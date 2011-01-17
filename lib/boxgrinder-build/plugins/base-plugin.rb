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
require 'boxgrinder-core/helpers/exec-helper'
require 'boxgrinder-core/helpers/log-helper'
require 'boxgrinder-build/helpers/image-helper'
require 'ostruct'
require 'hashery/opencascade'
require 'fileutils'
require 'logger'

module BoxGrinder
  class BasePlugin
    def initialize
      @plugin_config = {}

      @deliverables = OpenCascade.new
      @supported_oses = OpenCascade.new
      @target_deliverables = OpenCascade.new
      @dir = OpenCascade.new
    end

    def init(config, appliance_config, options = {})
      @config = config
      @appliance_config = appliance_config
      @options = options
      @log = options[:log] || Logger.new(STDOUT)
      @exec_helper = options[:exec_helper] || ExecHelper.new(:log => @log)
      @image_helper = options[:image_helper] || ImageHelper.new(@config, @appliance_config, :log => @log)
      @previous_plugin_info = options[:previous_plugin_info]
      @previous_deliverables = options[:previous_deliverables] || OpenCascade.new

      @plugin_info = options[:plugin_info]

      @dir.base = "#{@appliance_config.path.build}/#{@plugin_info[:name]}-plugin"
      @dir.tmp = "#{@dir.base}/tmp"

      read_plugin_config
      merge_plugin_config

      @move_deliverables = true
      @initialized = true

      after_init

      self
    end

    def register_deliverable(deliverable)
      raise "You can only register deliverables after the plugin is initialized, please initialize the plugin using init method." if @initialized.nil?
      raise "Please specify deliverables as Hash, not #{deliverable.class}." unless deliverable.is_a?(Hash)

      deliverable.each do |name, path|
        @deliverables[name] = "#{@dir.tmp}/#{path}"
        @target_deliverables[name] = "#{@dir.base}/#{path}"
      end
    end

    def register_supported_os(name, versions)
      raise "You can register supported operating system only after the plugin is initialized, please initialize the plugin using init method." if @initialized.nil?

      @supported_oses[name] = OpenCascade.new if @supported_oses[name].nil?
      @supported_oses[name] = versions
    end

    def is_supported_os?
      return true if @supported_oses.empty?
      return false unless !@supported_oses[@appliance_config.os.name].nil? and @supported_oses[@appliance_config.os.name].include?(@appliance_config.os.version)
      true
    end

    def supported_oses
      supported = ""

      @supported_oses.sort.each do |name, versions|
        supported << ", " unless supported.empty?
        supported << "#{name} (versions: #{versions.join(", ")})"
      end

      supported
    end

    def current_platform
      platform = :raw

      if @previous_plugin_info[:type] == :platform
        platform = @previous_plugin_info[:name]
      end unless @previous_plugin_info.nil?

      platform.to_s
    end

    def validate_plugin_config(fields = [], doc = nil)
      more_info = doc.nil? ? '' : "See #{doc} for more info"

      fields.each do |field|
        raise "Please specify a valid '#{field}' key in BoxGrinder configuration file: '#{@config.file}'. #{more_info}" if @plugin_config[field].nil?
      end
    end

    def execute(args = nil)
      raise "You can only execute the plugin after the plugin is initialized, please initialize the plugin using init method." if @initialized.nil?
    end

    def run(*args)
      unless is_supported_os?
        @log.error "#{@plugin_info[:full_name]} plugin supports following operating systems: #{supported_oses}. Your appliance contains #{@appliance_config.os.name} #{@appliance_config.os.version} operating system which is not supported by this plugin, sorry."
        return
      end

      FileUtils.rm_rf @dir.tmp
      FileUtils.mkdir_p @dir.tmp

      execute(*args)

      # TODO execute post commands for platform plugins here?

      @deliverables.each do |name, path|
        @log.trace "Moving '#{path}' deliverable to target destination '#{@target_deliverables[name]}'..."
        FileUtils.mv(path, @target_deliverables[name])
      end if @move_deliverables

      FileUtils.rm_rf @dir.tmp
    end

    def after_init
    end

    def after_execute
    end

    def deliverables_exists?
      raise "You can only check deliverables after the plugin is initialized, please initialize the plugin using init method." if @initialized.nil?

      exists = true

      @target_deliverables.each_value do |file|
        unless File.exists?(file)
          exists = false
          break
        end
      end

      exists
    end

    def deliverables
      @target_deliverables
    end

    def set_default_config_value(key, value)
      @plugin_config[key] = @plugin_config[key].nil? ? value : @plugin_config[key]
    end

    # This reads the plugin config from file
    def read_plugin_config
      return if @config[@plugin_info[:name].to_s].nil?

      @log.debug "Reading configuration for #{@plugin_info[:full_name]} plugin."

      @plugin_config = @config[@plugin_info[:name].to_s]
    end

    # This merges the plugin config with configuration provided in command line
    def merge_plugin_config
      config =
          case @plugin_info[:type]
            when :os
              @config.os_config
            when :platform
              @config.platform_config
            when :delivery
              @config.delivery_config
          end

      @plugin_config.merge!(config)
    end
  end
end
