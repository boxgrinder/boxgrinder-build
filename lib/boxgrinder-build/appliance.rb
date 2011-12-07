#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
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

require 'rubygems'
require 'hashery/opencascade'
require 'boxgrinder-core/helpers/log-helper'
require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/appliance-definition-helper'
require 'boxgrinder-core/helpers/appliance-config-helper'
require 'boxgrinder-build/helpers/plugin-helper'
require 'boxgrinder-build/managers/plugin-manager'

module BoxGrinder
  class Appliance
    attr_reader :plugin_chain
    attr_reader :appliance_config

    def initialize(appliance_definition, config = Config.new, options = {})
      @appliance_definition = appliance_definition
      @config = config
      @log = options[:log] || LogHelper.new(:level => @config.log_level)
    end

    # TODO: this is not very clean...
    def read_definition
      # first try to read as appliance definition file
      appliance_helper = ApplianceDefinitionHelper.new(:log => @log)
      appliance_helper.read_definitions(@appliance_definition)

      appliance_configs = appliance_helper.appliance_configs
      appliance_config = appliance_configs.first

      if appliance_config.nil?
        # Still nothing? Then try to read OS plugin specific format...
        PluginManager.instance.plugins[:os].each_value do |info|
          plugin = info[:class].new
          appliance_config = plugin.read_file(@appliance_definition) if plugin.respond_to?(:read_file)
          break unless appliance_config.nil?
        end
        appliance_configs = [appliance_config]

        raise ValidationError, "Ensure your appliance definition files have a .appl extension: #{File.basename(@appliance_definition)}." if appliance_config.nil?
      end

      appliance_config_helper = ApplianceConfigHelper.new(appliance_configs)
      @appliance_config = appliance_config_helper.merge(appliance_config.clone.init_arch).initialize_paths
    end

    def validate_definition
      os_plugin = PluginManager.instance.plugins[:os][@appliance_config.os.name.to_sym]

      raise "Unsupported operating system selected: #{@appliance_config.os.name}. Make sure you have installed right operating system plugin, see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#Operating_system_plugins. Supported OSes are: #{PluginManager.instance.plugins[:os].keys.join(", ")}" if os_plugin.nil?
      raise "Unsupported operating system version selected: #{@appliance_config.os.version}. Supported versions are: #{os_plugin[:versions].join(", ")}" unless @appliance_config.os.version.nil? or os_plugin[:versions].include?(@appliance_config.os.version)
    end

    # Here we initialize all required plugins and create a plugin chain.
    # Initialization involves also plugin configuration validation for specified plugin type.
    def initialize_plugins
      @plugin_chain = []

      os_plugin, os_plugin_info = PluginManager.instance.initialize_plugin(:os, @appliance_config.os.name.to_sym)
      os_plugin.init(@config, @appliance_config, os_plugin_info, :log => @log)

      @plugin_chain << {:plugin => os_plugin, :param => @appliance_definition}

      if platform_selected?
        platform_plugin, platform_plugin_info = PluginManager.instance.initialize_plugin(:platform, @config.platform)
        platform_plugin.init(@config, @appliance_config, platform_plugin_info, :log => @log, :previous_plugin => @plugin_chain.last[:plugin])

        @plugin_chain << {:plugin => platform_plugin}
      end

      if delivery_selected?
        delivery_plugin, delivery_plugin_info = PluginManager.instance.initialize_plugin(:delivery, @config.delivery)
        delivery_plugin.init(@config, @appliance_config, delivery_plugin_info, :log => @log, :previous_plugin => @plugin_chain.last[:plugin], :type => @config.delivery)

        @plugin_chain << {:plugin => delivery_plugin}
      end
    end

    def remove_old_builds
      @log.info "Removing previous builds for #{@appliance_config.name} appliance..."
      FileUtils.rm_rf(@appliance_config.path.build)
      @log.debug "Previous builds removed."
    end

    def execute_plugin_chain
      @log.info "Building '#{@appliance_config.name}' appliance for #{@appliance_config.hardware.arch} architecture."
      @plugin_chain.each { |p| execute_plugin(p[:plugin], p[:param]) }
    end

    def create
      @log.debug "Launching new build..."
      @log.trace "Used configuration: #{@config.to_yaml.gsub(/(\S*(key|account|cert|username|host|password)\S*).*:(.*)/, '\1' + ": <REDACTED>")}"

      # Let's load all plugins first
      PluginHelper.new(@config, :log => @log).load_plugins
      read_definition
      validate_definition
      initialize_plugins

      remove_old_builds if @config.force

      execute_plugin_chain

      self
    end

    def platform_selected?
      !(@config.platform == :none or @config.platform.to_s.empty? == nil)
    end

    def delivery_selected?
      !(@config.delivery == :none or @config.delivery.to_s.empty? == nil)
    end

    def execute_plugin(plugin, param = nil)
      if plugin.deliverables_exists?
        @log.info "Deliverables for #{plugin.plugin_info[:name]} #{plugin.plugin_info[:type]} plugin exists, skipping."
      else
        @log.debug "Executing #{plugin.plugin_info[:type]} plugin..."

        param.nil? ? plugin.run : plugin.run(param)

        @log.debug "#{plugin.plugin_info[:type].to_s.capitalize} plugin executed."
      end
      if plugin.plugin_info[:type] == :os
        FileUtils.chown_R(@config.uid, @config.gid, File.join(@config.dir.root, @config.dir.build))
        @log.debug "Lowering from root to user."
        change_user(@config.uid, @config.gid)
      end
    end

    def change_user(u, g)
      begin
        if Process::Sys.respond_to?(:setresgid) && Process::Sys.respond_to?(:setresuid)
          Process::Sys.setresgid(g, g, g)
          Process::Sys.setresuid(u, u, u)
          return
        end
      rescue NotImplementedError
      end

      begin
        # JRuby doesn't support saved ids, use this instead.
        Process.gid = g
        Process.egid = g
        Process.uid = u
        Process.euid = u
      rescue NotImplementedError
      end
    end
  end
end
