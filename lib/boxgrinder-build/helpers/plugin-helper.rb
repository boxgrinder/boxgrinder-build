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

module BoxGrinder
  class PluginHelper
    def initialize( options = {} )
      @log = options[:log] || Logger.new(STDOUT)
    end

    def load_plugins
      Dir["#{File.dirname( __FILE__ )}/../plugins/**/*.rb"].each {|file| require file }

      load_os_plugins
      load_platform_plugins

      self
    end

    def load_os_plugins
      @log.debug "Loading operating system plugins..."

      @os_plugins = OperatingSystemPluginManager.instance.initialize_plugins( :log => @log ).plugins

      @log.debug "We have #{@os_plugins.size} operating system plugin(s) registered"

      @os_plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]} #{plugin.info[:versions].join(', ')}."
      end

      @log.debug "Plugins loaded."
    end

    def load_platform_plugins
      @log.debug "Loading platform plugins..."

      @platform_plugins = PlatformPluginManager.instance.initialize_plugins( :log => @log ).plugins

      @log.debug "We have #{@platform_plugins.size} platform plugin(s) registered"

      @platform_plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]}."
      end

      @log.debug "Plugins loaded."
    end

    attr_reader :os_plugins
    attr_reader :platform_plugins
  end
end