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
require 'hashery/open_cascade'
require 'boxgrinder-core/helpers/log-helper'
require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/appliance-definition-helper'
require 'boxgrinder-core/helpers/appliance-config-helper'
require 'boxgrinder-build/helpers/plugin-helper'
require 'boxgrinder-build/managers/plugin-manager'
require 'boxgrinder-build/util/permissions/fs-monitor'
require 'boxgrinder-build/util/permissions/fs-observer'
require 'boxgrinder-build/util/permissions/user-switcher'

module BoxGrinder
  class Appliance
    attr_reader :plugin_chain
    attr_reader :appliance_config

    def initialize(appliance_definition, config = Config.new, options = {})
      @appliance_definition = appliance_definition
      @config = config
      @log = options[:log] || LogHelper.new(:level => @config.log_level)
    end

    def read_definition
      appliance_helper = ApplianceDefinitionHelper.new(:log => @log)
      appliance_helper.read_definitions(@appliance_definition)

      appliance_configs = appliance_helper.appliance_configs
      appliance_config = appliance_configs.first

      raise ValidationError, "Ensure your appliance definition file has a '.appl' extension: #{File.basename(@appliance_definition)}." if appliance_config.nil?

      appliance_config_helper = ApplianceConfigHelper.new(appliance_configs)
      @appliance_config = appliance_config_helper.merge(appliance_config.init_arch).initialize_paths
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
      initialize_plugin(os_plugin, os_plugin_info)

      if platform_selected?
        platform_plugin, platform_plugin_info = PluginManager.instance.initialize_plugin(:platform, @config.platform)
        initialize_plugin(platform_plugin, platform_plugin_info)
      end

      if delivery_selected?
        delivery_plugin, delivery_plugin_info = PluginManager.instance.initialize_plugin(:delivery, @config.delivery)
        # Here we need to specify additionally the type of the plugin, as some delivery plugins
        # can have multiple types of delivery implemented. See s3-plugin.rb for example.
        initialize_plugin(delivery_plugin, delivery_plugin_info, :type => @config.delivery)
      end
    end

    # Initializes the plugin by executing init, after_init, validate and after_validate methods.
    #
    # We can be sure only for init method because it is implemented internally in base-plugin.rb,
    # for all other methods we need to check if they exist.
    def initialize_plugin(plugin, plugin_info, options = {})
      options = {
        :log => @log
      }.merge(options)

      unless @plugin_chain.empty?
        options.merge!(:previous_plugin => @plugin_chain.last[:plugin])
      end

      plugin.init(@config, @appliance_config, plugin_info, options)

      # Execute callbacks if implemented
      #
      # Order is very important
      [:after_init, :validate, :after_validate].each do |callback|
        plugin.send(callback) if plugin.respond_to?(callback)
      end

      param = nil

      # For operating system plugins we need to inject appliance definition.
      if plugin_info[:type] == :os
        param = @appliance_definition
      end

      @plugin_chain << {:plugin => plugin, :param => param}
    end

    def remove_old_builds
      @log.info "Removing previous builds for #{@appliance_config.name} appliance..."
      FileUtils.rm_rf(@appliance_config.path.build)
      @log.debug "Previous builds removed."
    end

    def execute_plugin_chain
      @log.info "Building '#{@appliance_config.name}' appliance for #{@appliance_config.hardware.arch} architecture."

      @plugin_chain.each do |p|
        if @config.change_to_user
          execute_with_userchange(p)
        else
          execute_without_userchange(p)
        end
      end
    end

    # This creates the appliance by executing the plugin chain.
    #
    # Definition is read and validated. Afterwards a plugin chain is created
    # and every plugin in the chain is initialized and validated. The next step
    # is the execution of the plugin chain, step by step.
    #
    # Below you can find the whole process of bootstrapping a plugin.
    #
    #   Call            Scope
    #   ------------------------------------------
    #   initialize      required, internal
    #   init            required, internal
    #   after_init      optional, user implemented
    #   validate        optional, user implemented
    #   after_validate  optional, user implemented
    #   execute         required, user implemented
    #   after_execute   optional, user implemented
    #
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

        # Actually run the plugin
        param.nil? ? plugin.run : plugin.run(param)

        # Run after_execute callback, if implemented
        plugin.after_execute if plugin.respond_to?(:after_execute)

        @log.debug "#{plugin.plugin_info[:type].to_s.capitalize} plugin executed."
      end
    end

    private

    def execute_with_userchange(p)
      # Set ids to root if the next plugin requires root permissions
      uid, gid = p[:plugin].plugin_info[:require_root] ? [0, 0] : [@config.uid, @config.gid]

      UserSwitcher.change_user(uid, gid) do
        execute_plugin(p[:plugin], p[:param])
      end
      # Trigger ownership change before next plugin
      FSMonitor.instance.trigger      
    end
    
    def execute_without_userchange(p)
      execute_plugin(p[:plugin], p[:param])
    end
  end
end
