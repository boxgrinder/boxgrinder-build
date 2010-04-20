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


require 'yaml'

module BoxGrinder
  class ApplianceHelper
    def initialize( options = {}  )
      @log = options[:log] || Logger.new(STDOUT)
    end

    def read_definitions( definition_file )
      @log.debug "Reading definition from '#{definition_file}' file..."

      configs = {}

      appliance_config =
              case File.extname( definition_file )
                when '.appl', '.yml'
                  read_yaml( definition_file )
                when '.xml'
                  read_xml( definition_file )
                else
                  raise 'Unsupported file format for appliance definition file'
              end

      configs[appliance_config.name] = appliance_config

      appliance_config.appliances.each do |appliance_name|
        configs.merge!(read_definitions( "#{File.dirname( definition_file )}/#{appliance_name}.appl" ))
      end unless appliance_config.appliances.nil? or !appliance_config.appliances.is_a?(Array)

      configs
    end

    def read_yaml( file )
      begin
        definition = YAML.load_file( file )
      rescue => e
        raise "File '#{file}' could not be read"
      end

      appliance_config = ApplianceConfig.new

      appliance_config.name         = definition['name'] unless definition['name'].nil?
      appliance_config.summary      = definition['summary'] unless definition['summary'].nil?
      appliance_config.appliances   = definition['appliances'] unless definition['appliances'].nil?
      appliance_config.repos        = definition['repos'] unless definition['repos'].nil?

      appliance_config.version      = definition['version'].to_s unless definition['version'].nil?
      appliance_config.release      = definition['release'].to_s unless definition['release'].nil?

      unless definition['packages'].nil?
        appliance_config.packages.includes     = definition['packages']['includes'] unless definition['packages']['includes'].nil?
        appliance_config.packages.excludes     = definition['packages']['excludes'] unless definition['packages']['excludes'].nil?
      end

      unless definition['os'].nil?
        appliance_config.os.name      = definition['os']['name'].to_s unless definition['os']['name'].nil?
        appliance_config.os.version   = definition['os']['version'].to_s unless definition['os']['version'].nil?
        appliance_config.os.password  = definition['os']['password'].to_s unless definition['os']['password'].nil?
      end

      unless definition['hardware'].nil?
        appliance_config.hardware.cpus        = definition['hardware']['cpus']   unless definition['hardware']['cpus'].nil?
        appliance_config.hardware.memory      = definition['hardware']['memory'] unless definition['hardware']['memory'].nil?
        appliance_config.hardware.network     = definition['hardware']['network'] unless definition['hardware']['network'].nil?
        appliance_config.hardware.partitions  = definition['hardware']['partitions'] unless definition['hardware']['partitions'].nil?
      end

      unless definition['post'].nil?
        appliance_config.post.base      = definition['post']['base']    unless definition['post']['base'].nil?
        appliance_config.post.ec2       = definition['post']['ec2']     unless definition['post']['ec2'].nil?
        appliance_config.post.vmware    = definition['post']['vmware']  unless definition['post']['vmware'].nil?
      end

      appliance_config
    end

    def read_xml( file )
      raise "Reading XML files is not supported right now. File '#{file}' could not be read"
    end
  end
end
