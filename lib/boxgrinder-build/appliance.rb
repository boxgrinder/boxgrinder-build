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
require 'boxgrinder-build/helpers/release-helper'

module BoxGrinder
  class Appliance < Rake::TaskLib

    def initialize(  appliance_definition_file, options = {} )
      @config            = Config.new
      @appliance_definition_file  = appliance_definition_file
      @log               = options[:log] || Logger.new(STDOUT)
      @options           = options[:options]
    end

    def create
      appliance_configs       = ApplianceHelper.new( :log => @log ).read_definitions( @appliance_definition_file )
      appliance_config_helper = ApplianceConfigHelper.new( appliance_configs )

      @appliance_config = appliance_config_helper.merge(appliance_configs.values.first.clone.init_arch).initialize_paths

      ApplianceConfigValidator.new( @appliance_config, :os_plugins => OperatingSystemPluginManager.instance.plugins ).validate

      if @options.force
        @log.info "Removing previous builds for #{@appliance_config.name} appliance..."
        FileUtils.rm_rf( @appliance_config.path.dir.build )
        @log.debug "Previous builds removed."
      end

      base_deliverables       = execute_os_plugin
      platform_deliverables   = execute_platform_plugin( base_deliverables )
      delivery_deliverables   = execute_delivery_plugin( platform_deliverables )
    end

    def execute_os_plugin
      os_plugin = OperatingSystemPluginManager.instance.plugins[@appliance_config.os.name.to_sym]
      os_plugin.init( @config, @appliance_config, :log => @log )

      if deliverables_exists( os_plugin )
        @log.info "Deliverables for #{os_plugin.info[:name]} operating system plugin exists, skipping."
        return os_plugin.deliverables
      end

      @log.debug "Executing operating system plugin for #{@appliance_config.os.name}..."
      os_plugin.build
      @log.debug "Operating system plugin executed."

      os_plugin.deliverables
    end

    def execute_platform_plugin( base_deliverables )
      if @options.platform == :base
        @log.debug "Selected platform is base, skipping platform conversion."
        return base_deliverables
      end

      platform_plugin = PlatformPluginManager.instance.plugins[@options.platform]
      platform_plugin.init( @config, @appliance_config, :log => @log )

      if deliverables_exists( platform_plugin )
        @log.info "Deliverables for #{platform_plugin.info[:name]} platform plugin exists, skipping."
        return platform_plugin.deliverables
      end

      @log.debug "Executing platform plugin for #{@options.platform}..."
      platform_plugin.convert( base_deliverables[:disk] )
      @log.debug "Platform plugin executed."

      platform_plugin.deliverables
    end

    def execute_delivery_plugin( platfrom_deliverables )
      platfrom_deliverables
    end

    def deliverables_exists( plugin )
      File.exists?(plugin.deliverables[:disk]) and plugin.deliverables[:metadata].each_value { |file| File.exists?(file) }
    end

    def search_for_built_disks
      disks = Dir[ "#{@appliance_config.path.dir.raw.build_full}/*.raw" ]

      if disks.size == 0
        return nil
      else
        if disks.size == 1
          return disks.first
        else
          raise "More than 1 disk found. This should never happen"
        end
      end
    end
  end
end
