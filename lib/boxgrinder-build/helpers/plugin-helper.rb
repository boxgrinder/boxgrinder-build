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

module BoxGrinder
  class PluginHelper
    def initialize( options = {} )
      @log = options[:log] || Logger.new(STDOUT)
    end

    def load_plugins
      Dir["#{File.dirname( __FILE__ )}/../plugins/**/*-plugin.rb"].each { |file| require "boxgrinder-build/plugins/#{file.scan(/\/plugins\/(.*)\.rb$/).to_s}" }

      @os_plugins       = OperatingSystemPluginManager.instance.initialize_plugins( :log => @log ).plugins
      @platform_plugins = PlatformPluginManager.instance.initialize_plugins( :log => @log ).plugins
      @delivery_plugins = DeliveryPluginManager.instance.initialize_plugins( :log => @log ).plugins

      print_plugins( 'os' ) { @os_plugins }
      print_plugins( 'platform' ) { @platform_plugins }
      print_plugins( 'delivery' ) { @delivery_plugins }

      self
    end

    def print_plugins( type )
      @log.debug "Loading #{type} plugins..."

      plugins = yield

      @log.debug "We have #{plugins.size} #{type} plugin(s) registered"

      plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]}."
      end

      @log.debug "Plugins loaded."
    end

    attr_reader :os_plugins
    attr_reader :platform_plugins
    attr_reader :delivery_plugins
  end
end