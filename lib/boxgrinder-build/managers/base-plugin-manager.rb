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
  class BasePluginManager
    include Singleton

    def initialize
      @plugin_classes = []
      @plugins        = {}
    end

    def <<(plugin_class)
      @plugin_classes << plugin_class
    end

    def initialize_plugins( options = {} )
      log = options[:log] || Logger.new(STDOUT)

      @plugin_classes.each do |plugin_class|
        begin
          plugin = plugin_class.new
        rescue => e
          raise "Error while initializing #{plugin_class} plugin.", e
        end

        next unless plugin.respond_to?(:info)

        plugin.instance_variable_set( :@log, log )

        if @plugins[plugin.info[:name]].nil?
          @plugins[plugin.info[:name]] = plugin
        else
          raise "We already have registered plugin for #{plugin.info[:name]}."
        end
      end
      self
    end

    attr_reader :plugins

  end
end
