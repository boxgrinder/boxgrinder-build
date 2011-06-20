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

require 'boxgrinder-build/plugins/delivery/s3/s3-plugin'
require 'boxgrinder-build/plugins/delivery/sftp/sftp-plugin'
require 'boxgrinder-build/plugins/delivery/ebs/ebs-plugin'
require 'boxgrinder-build/plugins/delivery/local/local-plugin'
require 'boxgrinder-build/plugins/delivery/elastichosts/elastichosts-plugin'

require 'boxgrinder-build/plugins/platform/vmware/vmware-plugin'
require 'boxgrinder-build/plugins/platform/ec2/ec2-plugin'
require 'boxgrinder-build/plugins/platform/virtualbox/virtualbox-plugin'

require 'boxgrinder-build/plugins/os/centos/centos-plugin'
require 'boxgrinder-build/plugins/os/rhel/rhel-plugin'
require 'boxgrinder-build/plugins/os/fedora/fedora-plugin'
require 'boxgrinder-build/plugins/os/sl/sl-plugin'

module BoxGrinder
  class PluginHelper
    def initialize( config, options = {} )
      @options  = config
      @log      = options[:log] || LogHelper.new
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

    def read_and_require
      @options.additional_plugins.each do |plugin|
        @log.trace "Loading plugin '#{plugin}'..."

        begin
          require plugin
          @log.trace "- OK"
        rescue LoadError => e
          @log.trace "- Not found: #{e.message.strip.chomp}"
          @log.warn "Specified plugin: '#{plugin}' wasn't found. Make sure its name is correct, skipping..."
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
