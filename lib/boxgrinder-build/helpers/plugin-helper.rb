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
require 'boxgrinder-build/managers/plugin-manager'
require 'boxgrinder-core/helpers/log-helper'

module BoxGrinder
  class PluginHelper
    def initialize( options = {} )
      @log      = options[:log] || LogHelper.new
      @options  = options[:options]
    end

    def load_plugins
      read_and_require

      @os_plugins       = PluginManager.instance.plugins[:os]
      @platform_plugins = PluginManager.instance.plugins[:platform]
      @delivery_plugins = PluginManager.instance.plugins[:delivery]

      print_plugins( 'os' ) { @os_plugins }
      print_plugins( 'platform' ) { @platform_plugins }
      print_plugins( 'delivery' ) { @delivery_plugins }

      self
    end

    def parse_plugin_list
      plugins = []

      unless @options.plugins.nil? or @options.plugins.empty? 
        plugins = @options.plugins.gsub('\'', '').gsub('"', '').split(',')
        plugins.each { |plugin| plugin.chomp!; plugin.strip! }
      end

      plugins
    end

    def read_and_require
      plugins = %w(boxgrinder-build-fedora-os-plugin boxgrinder-build-rhel-os-plugin boxgrinder-build-centos-os-plugin boxgrinder-build-ec2-platform-plugin boxgrinder-build-vmware-platform-plugin boxgrinder-build-s3-delivery-plugin boxgrinder-build-sftp-delivery-plugin boxgrinder-build-local-delivery-plugin boxgrinder-build-ebs-delivery-plugin) + parse_plugin_list

      plugins.flatten.each do |plugin|
        @log.trace "Requiring plugin '#{plugin}'..."

        begin
          require plugin
        rescue LoadError
          @log.warn "Specified plugin: '#{plugin}' wasn't found. Make sure its name is correct, skipping..." unless plugin.match(/^boxgrinder-build-(.*)-plugin/)
        end
      end
    end

    def print_plugins( type )
      @log.debug "Loading #{type} plugins..."

      plugins = yield

      @log.debug "We have #{plugins.size} #{type} plugin(s) registered"

      plugins.each do |plugin_name_or_type, plugin_info|
        @log.debug "- #{plugin_name_or_type} plugin for #{plugin_info[:full_name]}."
      end

      @log.debug "Plugins loaded."
    end

    attr_reader :os_plugins
    attr_reader :platform_plugins
    attr_reader :delivery_plugins
  end
end
