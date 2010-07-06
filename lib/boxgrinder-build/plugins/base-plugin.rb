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
require 'logger'

module BoxGrinder
  class BasePlugin
    def init(config, appliance_config, options = {})
      @config           = config
      @appliance_config = appliance_config
      @options          = options

      @log              = options[:log]           || Logger.new(STDOUT)
      @exec_helper      = options[:exec_helper]   || ExecHelper.new( :log => @log )

      @plugin_config    = {}
      @deliverables     = Hash.new({})

      if self.respond_to?(:info)
        @config_file = "#{ENV['HOME']}/.boxgrinder/plugins/#{self.info[:name]}"

        read_plugin_config

        @deliverables[:disk]      = nil
        @deliverables[:platform]  = self.info[:name]
      end

      after_init

      @initialized = true

      self
    end

    attr_reader :deliverables

    def validate_plugin_config(fields = [], doc = nil)
      more_info = doc.nil? ? '' : "See #{doc} for more info"

      raise "Not valid configuration file for #{info[:name]} plugin. Please create valid '#{@config_file}' file. #{more_info}" if @plugin_config.nil?

      fields.each do |field|
        raise "Please specify a valid #{field} in plugin configuration file: '#{@config_file}'. #{more_info}" if @plugin_config[field].nil?
      end
    end

    def execute(args = nil)
      raise "Conversion cannot be started before the plugin isn't initialized" if @initialized.nil?
    end

    def after_init
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

    def customize(disk_path)
      raise "Customizing cannot be started until the plugin isn't initialized" if @initialized.nil?

      ApplianceCustomizeHelper.new(@config, @appliance_config, disk_path, :log => @log).customize do |guestfs, guestfs_helper|
        yield guestfs, guestfs_helper
      end
    end
  end
end