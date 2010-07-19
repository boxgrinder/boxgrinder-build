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

require 'boxgrinder-core/helpers/exec-helper'
require 'boxgrinder-build/helpers/guestfs-helper'
require 'ostruct'
require 'openhash/openhash'
require 'fileutils'
require 'logger'

module BoxGrinder
  class BasePlugin
    def init(config, appliance_config, options = {})
      @config           = config
      @appliance_config = appliance_config
      @options          = options

      @log              = options[:log]           || Logger.new(STDOUT)
      @exec_helper      = options[:exec_helper]   || ExecHelper.new( :log => @log )

      @plugin_info            = options[:plugin_info]
      @previous_plugin_info   = options[:previous_plugin_info]

      @previous_deliverables  = options[:previous_deliverables] || {}
      @plugin_config          = {}

      @deliverables           = OpenHash.new
      @target_deliverables    = OpenHash.new
      @dir                    = OpenHash.new

      @dir.base               = "#{@appliance_config.path.build}/#{@plugin_info[:name]}-plugin"
      @dir.tmp                = "#{@dir.base}/tmp"

      @config_file            = "#{ENV['HOME']}/.boxgrinder/plugins/#{@plugin_info[:name]}"

      read_plugin_config

      @initialized = true

      after_init

      self
    end

    def register_deliverable( deliverable )
      raise "You can only register deliverables after the plugin is initialized, please initialize the plugin using init method." if @initialized.nil?
      raise "Please specify deliverables as Hash, not #{deliverable.class}." unless deliverable.is_a?(Hash)

      deliverable.each do |name, path|
        @deliverables[name]          = "#{@dir.tmp}/#{path}"
        @target_deliverables[name]   = "#{@dir.base}/#{path}"
      end
    end

    def validate_plugin_config(fields = [], doc = nil)
      more_info = doc.nil? ? '' : "See #{doc} for more info"

      raise "Not valid configuration file for #{info[:name]} plugin. Please create valid '#{@config_file}' file. #{more_info}" if @plugin_config.nil?

      fields.each do |field|
        raise "Please specify a valid '#{field}' key in plugin configuration file: '#{@config_file}'. #{more_info}" if @plugin_config[field].nil?
      end
    end

    def execute(args = nil)
      raise "You can only execute the plugin after the plugin is initialized, please initialize the plugin using init method." if @initialized.nil?
    end

    def run( *args )
      FileUtils.rm_rf @dir.tmp
      FileUtils.mkdir_p @dir.tmp

      execute( *args )

      after_execute
    end

    def after_init
    end

    def after_execute
      @deliverables.each do |name, path|
        @log.trace "Moving '#{path}' deliverable to target destination '#{@target_deliverables[name]}'..."
        FileUtils.mv( path, @target_deliverables[name] )
      end

      FileUtils.rm_rf @dir.tmp
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

    def read_plugin_config
      return unless File.exists?(@config_file)

      @log.debug "Reading configuration file for #{self.class.name}."

      begin
        @plugin_config = YAML.load_file(@config_file)
      rescue
        raise "An error occurred while reading configuration file #{@config_file} for #{self.class.name}. Is it a valid YAML file?"
      end
    end

    # TODO consider removing this from BasePlugin and moving to another base class
    def customize( disk_path )
      raise "Customizing cannot be started until the plugin isn't initialized" if @initialized.nil?

      GuestFSHelper.new( disk_path, :log => @log ).customize  do |guestfs, guestfs_helper|
        yield guestfs, guestfs_helper
      end
    end
  end
end