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

require 'singleton'

module BoxGrinder
  module Plugins
    def plugin( args )
      PluginManager.instance.register_plugin( args )
    end
  end
end

include BoxGrinder::Plugins

module BoxGrinder
  class PluginManager
    include Singleton

    def initialize
      @plugins = { :delivery => {}, :os => {}, :platform => {}}
    end

    def register_plugin( info )
      validate_plugin_info( info )

      raise "We already have registered plugin for #{info[:name]}." unless @plugins[info[:name]].nil?
      @plugins[info[:type]][info[:name]] = info

      self
    end

    def validate_plugin_info( info )
      raise "No name specified for your plugin" if info[:name].nil?
      raise "No class specified for your plugin" if info[:class].nil?
      raise "No type specified for your plugin" if info[:type].nil?
    end

    def initialize_plugin( type, name )
      plugins = @plugins[type]
      # this should never happen
      raise "There are no #{type} plugins." if plugins.nil?
      plugin_info = plugins[name]
      raise "There is no #{type} plugin registered for '#{name}' type/name." if plugin_info.nil?

      begin
        plugin = plugin_info[:class].new
      rescue => e
        raise "Error while initializing #{plugin_info[:class]} plugin.", e
      end

      [ plugin, plugin_info ]
    end

    def plugin_types( type )
      types = []

      available_plugins_for_selected_type = @plugins[type]

      unless available_plugins_for_selected_type.nil?
        available_plugins_for_selected_type.each_value do |info|
          types << info[:types] unless info[:types].nil?
          types << info[:name]
        end
      end

      types.flatten
    end

    attr_reader :plugins
    attr_accessor :log
  end
end
