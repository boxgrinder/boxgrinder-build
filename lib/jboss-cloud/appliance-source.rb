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
  class ApplianceSource < Rake::TaskLib
    def initialize( config, appliance_config )
      @config                = config
      @appliance_config      = appliance_config
      
      @appliance_dir         = "#{@config.dir_appliances}/#{@appliance_config.name}"
      @appliance_build_dir   = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      
      define
    end
    
    def define
      directory @appliance_build_dir
      
      source_files = FileList.new( "#{@appliance_dir}/*/**" )      
      source_tar_gz = "#{@config.dir_top}/#{@appliance_config.os_path}/SOURCES/#{@appliance_config.name}-#{@config.version}.tar.gz"
      
      file source_tar_gz => [ @appliance_build_dir, source_files, 'rpm:topdir' ].flatten do
        stage_directory = "#{@appliance_build_dir}/sources/#{@appliance_config.name}-#{@config.version}/appliances"
        FileUtils.rm_rf stage_directory
        FileUtils.mkdir_p stage_directory
        FileUtils.cp_r( "#{@appliance_dir}/", stage_directory  )
        
        defs = { }
        
        defs['appliance_name']        = @appliance_config.name
        defs['appliance_summary']     = @appliance_config.summary
        defs['appliance_version']     = @config.version_with_release
        
        def defs.method_missing(sym,*args)
          self[ sym.to_s ]
        end
        
        puppet_file = "#{stage_directory}/#{@appliance_config.name}/#{@appliance_config.name}.pp"
        
        erb = ERB.new( File.read( puppet_file ) )
        
        File.open( puppet_file, 'w' ) {|f| f.write( erb.result( defs.send( :binding ) ) ) }
        
        Dir.chdir( "#{@appliance_build_dir}/sources" ) do
          command = "tar zcvf #{@config.dir_root}/#{source_tar_gz} #{@appliance_config.name}-#{@config.version}/"
          execute_command( command )
        end
      end
      
      desc "Build source for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:source" => [ source_tar_gz ]
    end
    
  end
end
