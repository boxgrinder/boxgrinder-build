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

require 'boxgrinder-build/managers/operating-system-plugin-manager'
require 'boxgrinder-build/managers/platform-plugin-manager'
require 'boxgrinder-build/managers/delivery-plugin-manager'
require 'boxgrinder-build/managers/delivery-plugin-manager'
require 'rubygems'

module BoxGrinder
  module Plugins
    def plugin( args )
      PluginReader.instance.register_plugin( args )
    end
  end
end

include BoxGrinder::Plugins

module BoxGrinder
  class PluginReader
    include Singleton

    attr_writer :log

    def register_plugin( args )
      validate_plugin_args( args )

      #TODO add here logger!
      case args[:type]
        when :os
          OperatingSystemPluginManager.instance.initialize_plugin( args, :log => @log )
        when :platform
          PlatformPluginManager.instance.initialize_plugin( args, :log => @log )
        when :delivery
          DeliveryPluginManager.instance.initialize_plugin( args, :log => @log )
        else
          raise "Unsupported type of plugin: #{args[:type]}"
      end
    end

    def validate_plugin_args(args)
      raise "No class specified" if args[:class].nil?
      raise "No type specified" if args[:type].nil?
    end
  end

  class PluginHelper
    def initialize( options = {} )
      @log      = options[:log] || Logger.new(STDOUT)
      @options  = options[:options]
    end

    def load_plugins
      PluginReader.instance.log = @log

      read_and_require

      @os_plugins       = OperatingSystemPluginManager.instance.plugins
      @platform_plugins = PlatformPluginManager.instance.plugins
      @delivery_plugins = DeliveryPluginManager.instance.plugins

      print_plugins( 'os' ) { @os_plugins }
      print_plugins( 'platform' ) { @platform_plugins }
      print_plugins( 'delivery' ) { @delivery_plugins }

      self
    end

    def parse_plugin_list
      plugins = nil

      unless @options.plugins.nil?
        plugins = @options.plugins.gsub('\'', '').gsub('"', '').split(',')
        plugins.each { |plugin| plugin.chomp!; plugin.strip! }
      end

      plugins
    end

    def read_and_require
      plugins = parse_plugin_list || %w(boxgrinder-build-fedora-os-plugin boxgrinder-build-rhel-os-plugin boxgrinder-build-centos-os-plugin boxgrinder-build-ec2-platform-plugin)

      plugins.each do |plugin|
        @log.trace "Requiring plugin '#{plugin}'..."

        gem plugin
        require plugin
      end
    end

    def print_plugins( type )
      @log.debug "Loading #{type} plugins..."

      plugins = yield

      @log.debug "We have #{plugins.size} #{type} plugin(s) registered"

      plugins.each_value do |plugin_info|
        @log.debug "- plugin for #{plugin_info[:info][:full_name]}."
      end

      @log.debug "Plugins loaded."
    end

    def deliverables_exists?( deliverables )
      return false unless File.exists?(deliverables[:disk])

      [:metadata, :other].each do |deliverable_type|
        deliverables[deliverable_type].each_value do |file|
          return false unless File.exists?(file)
        end
      end

      true
    end

    def deliverables_array( deliverables )
      files = []

      files << deliverables[:disk]

      [:metadata, :other].each do |deliverable_type|
        deliverables[deliverable_type].each_value do |file|
          file << file
        end
      end

      files
    end

    attr_reader :os_plugins
    attr_reader :platform_plugins
    attr_reader :delivery_plugins
  end
end