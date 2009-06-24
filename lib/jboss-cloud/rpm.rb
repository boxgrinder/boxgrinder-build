# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'rake/tasklib'

module JBossCloud
  class RPM < Rake::TaskLib

    def self.provides
      @provides ||= {}
    end

    def self.provides_rpm_path
      @provides_rpm_path ||= {}
    end

    def initialize( config, spec_file, log )
      @config     = config
      @spec_file  = spec_file
      @log        = log

      @exec_helper = ExecHelper.new( @log )
      @simple_name = File.basename( @spec_file, ".spec" )

      @rpm_release    = nil
      @rpm_version    = nil
      @rpm_is_noarch  = nil

      Dir.chdir( File.dirname( @spec_file ) ) do
        @rpm_release     = `rpm --specfile #{@simple_name}.spec -q --qf '%{Release}\\n' 2> /dev/null`.split("\n").first
        @rpm_version     = `rpm --specfile #{@simple_name}.spec -q --qf '%{Version}\\n' 2> /dev/null`.split("\n").first
        @rpm_is_noarch   = `rpm --specfile #{@simple_name}.spec -q --qf '%{arch}\\n' 2> /dev/null`.split("\n").first == "noarch"
      end

      @rpm_arch = @rpm_is_noarch ? "noarch" : @config.build_arch

      @rpm_file             = "#{@config.dir.top}/#{@config.os_path}/RPMS/#{@rpm_arch}/#{@simple_name}-#{@rpm_version}-#{@rpm_release}.#{@rpm_arch}.rpm"
      @rpm_file_basename    = File.basename( @rpm_file )

      RPM.provides[@simple_name]            = "#{@simple_name}-#{@rpm_version}-#{@rpm_release}"
      RPM.provides_rpm_path[@simple_name]   = @rpm_file

      RPMGPGSign.new( @config, @spec_file )

      build_source_dependencies( @rpm_file, @rpm_version, @rpm_release )

      define_tasks
    end

    def define_tasks

      desc "Build #{@simple_name} RPM."
      task "rpm:#{@simple_name}" => [ @rpm_file ]

      file @rpm_file => [ 'rpm:topdir', @spec_file ] do
        build_rpm
      end

      desc "Build all RPMs"
      task 'rpm:all' => [ @rpm_file ]
    end

    def build_rpm
      @log.info "Building package '#{@rpm_file_basename}'..."

      begin
        Dir.chdir( File.dirname( @spec_file ) ) do
          @exec_helper.execute( "rpmbuild --define '_topdir #{@config.dir_root}/#{@config.dir.top}/#{@config.os_path}' --target #{@rpm_arch} -ba #{@simple_name}.spec" )
        end
      rescue => e
        ExceptionHelper.new( @log ).log_and_exit( e )
      end

      @log.info "Package '#{@rpm_file_basename}' was built successfully."

      Rake::Task[ 'rpm:repodata:force' ].reenable
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
      source_file     = "#{@config.dir.top}/#{@config.os_path}/SOURCES/#{source_basename}"

      file rpm_file => [ source_file ]

      #if ( source_file == APPLIANCE_SOURCE_FILE )
      #  nothing
      # else

      file source_file do
        FileUtils.cp( "#{@config.dir_src}/#{source}", "#{source_file}" ) if File.exists?( "#{@config.dir.src}/#{source_basename}" )
        FileUtils.cp( "#{@config.dir.base}/src/#{source}", "#{source_file}" ) if File.exists?( "#{@config.dir.base}/src/#{source_basename}" )
      end
    end

    def handle_remote_source(rpm_file, source)
      source_basename = File.basename( source )

      source_file       = "#{@config.dir.top}/#{@config.os_path}/SOURCES/#{source_basename}"
      source_cache_file = "#{@config.dir_src_cache}/#{source_basename}"

      file rpm_file => [ source_file ]

      file source_file => [ 'rpm:topdir' ] do
        if ( ! File.exist?( source_cache_file ) )
          FileUtils.mkdir_p( @config.dir_src_cache )
          @exec_helper.execute( "wget #{source} -O #{source_cache_file} --progress=bar:mega" )
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
        elsif ( line =~ /Source[0-9]*: (.*)/ )
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
