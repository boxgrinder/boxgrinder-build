require 'rake/tasklib'

module JBossCloud

  class ApplianceSource < Rake::TaskLib

    def initialize( config, appliance_dir )
      @config                = config
      @build_dir             = Config.get.dir_build
      @topdir                = Config.get.dir_top
      @version               = Config.get.version
      @release               = Config.get.release
      @appliance_dir         = appliance_dir
      @simple_name           = @config.name
      @super_simple_name     = File.basename( @simple_name, '-appliance' )
      @appliance_build_dir   = "#{@build_dir}/appliances/#{@config.arch}/#{@simple_name}"
      define
    end

    def define
      directory @appliance_build_dir

      source_files = FileList.new( "#{@appliance_dir}/*/**" )

      file "#{@topdir}/SOURCES/#{@simple_name}-#{@version}.tar.gz"=>[ @appliance_build_dir, source_files, 'rpm:topdir' ].flatten do
        stage_directory = "#{@appliance_build_dir}/sources/#{@simple_name}-#{@version}/appliances"
        FileUtils.rm_rf stage_directory
        FileUtils.mkdir_p stage_directory
        FileUtils.cp_r( "#{@appliance_dir}/", stage_directory  )
        Dir.chdir( "#{@appliance_build_dir}/sources" ) do
          command = "tar zcvf #{Config.get.dir_root}/#{@topdir}/SOURCES/#{@simple_name}-#{@version}.tar.gz #{@simple_name}-#{@version}/"
          execute_command( command )
        end
      end
 
      desc "Build source for #{@super_simple_name} appliance"
      task "appliance:#{@simple_name}:source" => [ "#{@topdir}/SOURCES/#{@simple_name}-#{@version}.tar.gz" ]
    end

  end
end
