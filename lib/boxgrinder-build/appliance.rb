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

require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/appliance-helper'
require 'boxgrinder-core/helpers/appliance-config-helper'
require 'boxgrinder-core/validators/appliance-config-validator'

module BoxGrinder
  class Appliance

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

      ApplianceConfigValidator.new( @appliance_config, :os_plugins => PluginManager.instance.plugins[:os] ).validate

      if @options.force
        @log.info "Removing previous builds for #{@appliance_config.name} appliance..."
        FileUtils.rm_rf( @appliance_config.path.build )
        @log.debug "Previous builds removed."
      end

      base_plugin_output       = execute_os_plugin
      platform_plugin_output   = execute_platform_plugin( base_plugin_output )

      execute_delivery_plugin( platform_plugin_output )
    end

    def execute_os_plugin
      os_plugin, os_plugin_info = PluginManager.instance.initialize_plugin(:os, @appliance_config.os.name.to_sym )
      os_plugin.init( @config, @appliance_config, :log => @log, :plugin_info => os_plugin_info )

      if os_plugin.deliverables_exists?
        @log.info "Deliverables for #{os_plugin_info[:name]} operating system plugin exists, skipping."
        return { :deliverables => os_plugin.deliverables }
      end

      @log.debug "Executing operating system plugin for #{@appliance_config.os.name}..."
      os_plugin.run
      @log.debug "Operating system plugin executed."

      { :deliverables => os_plugin.deliverables, :plugin_info => os_plugin_info }
    end

    def execute_platform_plugin( previous_plugin_output )
      if @options.platform == :none or @options.platform == nil
        @log.debug "No platform selected, skipping platform conversion."
        return previous_plugin_output
      end

      platform_plugin, platform_plugin_info = PluginManager.instance.initialize_plugin(:platform, @options.platform )
      platform_plugin.init( @config, @appliance_config, :log => @log, :plugin_info => platform_plugin_info, :previous_plugin_info => previous_plugin_output[:plugin_info], :previous_deliverables => previous_plugin_output[:deliverables] )

      if platform_plugin.deliverables_exists?
        @log.info "Deliverables for #{platform_plugin_info[:name]} platform plugin exists, skipping."
        return { :deliverables => platform_plugin.deliverables, :plugin_info => platform_plugin_info }
      end

      @log.debug "Executing platform plugin for #{@options.platform}..."
      platform_plugin.run
      @log.debug "Platform plugin executed."

      { :deliverables => platform_plugin.deliverables, :plugin_info => platform_plugin_info }
    end

    def execute_delivery_plugin( previous_plugin_output )
      if @options.delivery == :none or @options.delivery == nil
        @log.debug "No delivery method selected, skipping delivering."
        return
      end

      delivery_plugin, delivery_plugin_info = PluginManager.instance.initialize_plugin(:delivery, @options.delivery )
      delivery_plugin.init( @config, @appliance_config, :log => @log, :plugin_info => delivery_plugin_info, :previous_plugin_info => previous_plugin_output[:plugin_info], :previous_deliverables => previous_plugin_output[:deliverables] )

      if @options.delivery != delivery_plugin_info[:name]
        delivery_plugin.run( @options.delivery )
      else
        delivery_plugin.run
      end
    end
  end
end
