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
require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/appliance-helper'
require 'boxgrinder-core/helpers/appliance-config-helper'
require 'boxgrinder-core/validators/appliance-config-validator'

module BoxGrinder
  class Appliance < Rake::TaskLib

    def initialize( appliance_definition_file, options = {} )
      @config                     = Config.new
      @appliance_definition_file  = appliance_definition_file
      @log                        = options[:log] || Logger.new(STDOUT)
      @options                    = options[:options]

      @config.name            = @options.name
      @config.version.version = @options.version
      @config.version.release = nil
    end

    def create
      appliance_configs, appliance_config = ApplianceHelper.new( :log => @log ).read_definitions( @appliance_definition_file )
      appliance_config_helper             = ApplianceConfigHelper.new( appliance_configs )

      @appliance_config = appliance_config_helper.merge(appliance_config.clone.init_arch).initialize_paths

      ApplianceConfigValidator.new( @appliance_config, :os_plugins => OperatingSystemPluginManager.instance.plugins ).validate

      if @options.force
        @log.info "Removing previous builds for #{@appliance_config.name} appliance..."
        FileUtils.rm_rf( @appliance_config.path.dir.build )
        @log.debug "Previous builds removed."
      end

      base_deliverables       = execute_os_plugin
      platform_deliverables   = execute_platform_plugin( base_deliverables )

      execute_delivery_plugin( platform_deliverables )
    end

    def execute_os_plugin
      os_plugin = OperatingSystemPluginManager.instance.plugins[@appliance_config.os.name.to_sym]
      os_plugin.init( @config, @appliance_config, :log => @log )

      if deliverables_exists( os_plugin.deliverables )
        @log.info "Deliverables for #{os_plugin.info[:name]} operating system plugin exists, skipping."
        return os_plugin.deliverables
      end

      @log.debug "Executing operating system plugin for #{@appliance_config.os.name}..."
      os_plugin.execute
      @log.debug "Operating system plugin executed."

      os_plugin.deliverables
    end

    def execute_platform_plugin( deliverables )
      if @options.platform == :none
        @log.debug "No platform selected, skipping platform conversion."
        return deliverables
      end

      platform_plugin = PlatformPluginManager.instance.plugins[@options.platform]
      platform_plugin.init( @config, @appliance_config, :log => @log )

      if deliverables_exists( platform_plugin.deliverables )
        @log.info "Deliverables for #{platform_plugin.info[:name]} platform plugin exists, skipping."
        return platform_plugin.deliverables
      end

      @log.debug "Executing platform plugin for #{@options.platform}..."
      platform_plugin.execute( deliverables[:disk] )
      @log.debug "Platform plugin executed."

      platform_plugin.deliverables
    end

    def execute_delivery_plugin( deliverables )
      if @options.delivery == :none
        @log.debug "No delivery method selected, skipping delivering."
        return deliverables
      end

      delivery_plugin = DeliveryPluginManager.instance.types[@options.delivery]
      delivery_plugin.init( @config, @appliance_config, :log => @log )
      delivery_plugin.execute( deliverables, @options.delivery )
    end

    # TODO: move this to plugin (os,platform,delivery)
    def deliverables_exists( deliverables )
      return false unless File.exists?(deliverables[:disk])

      [:metadata, :other].each do |deliverable_type|
        deliverables[deliverable_type].each_value do |file|
          return false unless File.exists?(file)
        end
      end

      true
    end
  end
end
