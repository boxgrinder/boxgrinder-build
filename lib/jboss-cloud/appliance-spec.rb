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
require 'yaml'
require 'erb'

module JBossCloud
  class ApplianceSpec < Rake::TaskLib

    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config

      define
    end

    def define

      appliance_build_dir    = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      spec_file              = "#{appliance_build_dir}/#{@appliance_config.name}.spec"

      definition             = YAML.load_file( "#{@config.dir_appliances}/#{@appliance_config.name}/#{@appliance_config.name}.appl" )
      definition['name']     = @appliance_config.name
      definition['version']  = @config.version.version
      definition['release']  = @config.version.release
      definition['version_with_release']  = @config.version_with_release
      definition['packages'] = Array.new if definition['packages'] == nil
      definition['packages'] += @appliance_config.appliances.select {|v| !v.eql?(@appliance_config.name)}

      def definition.method_missing(sym,*args)
        self[ sym.to_s ]
      end

      file spec_file => [ appliance_build_dir ] do
        template = File.dirname( __FILE__ ) + "/appliance.spec.erb"

        erb = ERB.new( File.read( template ) )
        File.open( spec_file, 'w' ) {|f| f.write( erb.result( definition.send( :binding ) ) ) }
      end

      for p in definition['packages'] 
        if ( JBossCloud::RPM.provides.keys.include?( p ) )

          file "#{@config.dir_top}/#{@appliance_config.os_path}/RPMS/noarch/#{@appliance_config.name}-#{@config.version_with_release}.noarch.rpm"=>[ "rpm:#{p}" ]
        end
      end
 
      desc "Build RPM spec for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:spec" => [ spec_file ]
    end

  end

end

