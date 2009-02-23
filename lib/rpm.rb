require 'rake/tasklib'

module JBossCloud
  class RPM < Rake::TaskLib

    def self.provides
      @provides ||= {}
    end

    def self.provides_rpm_path
      @provides_rpm_path ||= {}
    end

    def initialize(spec_file)
      @topdir = Config.get.dir_top
      @spec_file = spec_file
      define
    end

    def define
      simple_name = File.basename( @spec_file, ".spec" )
      release = nil
      version = nil
      is_noarch = nil
      Dir.chdir( File.dirname( @spec_file ) ) do
        release = `rpm --specfile #{simple_name}.spec -q --qf '%{Release}\\n' 2> /dev/null`.split("\n").first
        version = `rpm --specfile #{simple_name}.spec -q --qf '%{Version}\\n' 2> /dev/null`.split("\n").first
        is_noarch = `rpm --specfile #{simple_name}.spec -q --qf '%{arch}\\n' 2> /dev/null`.split("\n").first == "noarch"
      end

      arch = is_noarch ? "noarch" : Config.get.build_arch

      rpm_file = "#{@topdir}/RPMS/#{arch}/#{simple_name}-#{version}-#{release}.#{arch}.rpm"
      JBossCloud::RPM.provides[simple_name] = "#{simple_name}-#{version}-#{release}"
      JBossCloud::RPM.provides_rpm_path[simple_name] = rpm_file

      desc "Build #{simple_name} RPM."
      task "rpm:#{simple_name}"=>[ rpm_file ]

      file rpm_file => [ 'rpm:topdir', @spec_file ] do
        Dir.chdir( File.dirname( @spec_file ) ) do
          exit_status = execute_command "rpmbuild --define '_topdir #{Config.get.dir_root}/#{@topdir}' --target #{arch} -ba #{simple_name}.spec"
          unless exit_status
            puts "\nBuilding #{simple_name} failed! Hint: consult above messages.\n\r"
            abort
          end
        end
      end

      task 'rpm:all' => [ rpm_file ]

      build_source_dependencies( rpm_file, version, release )
    end
    

    def handle_requirement(rpm_file, requirement)
      if JBossCloud::RPM.provides.keys.include?( requirement )
        file rpm_file  => [ JBossCloud::RPM.provides_rpm_path[ requirement ] ]
      end
    end

    def handle_source(rpm_file, source, version, release)
      source = substitute_version_info( source, version, release )
      if ( source =~ %r{http://} )
        handle_remote_source( rpm_file, source )
      else
        handle_local_source( rpm_file, source )
      end
    end

    def handle_local_source(rpm_file, source)
      source_basename = File.basename( source )
      source_file     = "#{@topdir}/SOURCES/#{source_basename}"

      file rpm_file => [ source_file ]
 
      #if ( source_file == APPLIANCE_SOURCE_FILE )
      #  nothing
      # else
       
      file source_file=>[ "src/#{source_basename}" ] do
        FileUtils.cp( "#{JBossCloud::Config.get.dir_root}/src/#{source}", "#{@topdir}/SOURCES/#{source_basename}" )
      end
    
    end

    def handle_remote_source(rpm_file, source)
      source_basename = File.basename( source )

      source_file       = "#{@topdir}/SOURCES/#{source_basename}"
      source_cache_file = "#{JBossCloud::Config.get.dir_src_cache}/#{source_basename}"

      file rpm_file => [ source_file ]

      file source_file => [ 'rpm:topdir' ] do
        if ( ! File.exist?( source_cache_file ) )
          FileUtils.mkdir_p( JBossCloud::Config.get.dir_src_cache )
          execute_command( "wget #{source} -O #{source_cache_file} --progress=bar:mega" )
        end
        FileUtils.cp( source_cache_file, source_file )
      end
    end

    def substitute_version_info(str, version=nil, release=nil)
      s = str.dup
      s.gsub!( /%\{version\}/, version ) if version
      s.gsub!( /%\{release\}/, release ) if release
      s
    end

    def build_source_dependencies( rpm_file, version=nil, release=nil)
      File.open( @spec_file).each_line do |line|
        line.gsub!( /#.*$/, '' )
        if ( line =~ /Requires: (.*)/ )
          requirement = $1.strip
          handle_requirement( rpm_file, requirement )
        elsif ( line =~ /Source[0-9]+: (.*)/ )
          source = $1.strip
          handle_source( rpm_file, source, version, release  )
        elsif ( line =~ /Patch[0-9]*: (.*)/ )
          patch = $1.strip
          handle_source( rpm_file, patch, version, release  )
        end
      end
    end
  end
end

desc "Build all RPMs"
task 'rpm:all'
