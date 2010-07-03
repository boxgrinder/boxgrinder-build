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
      @plugins = {}
    end

    def initialize_plugin( info, options = {} )
      raise "We already have registered plugin for #{info[:name]}." unless @plugins[info[:name]].nil?

      begin
        plugin = info[:class].new
      rescue => e
        raise "Error while initializing #{info[:class]} plugin.", e
      end

      plugin.instance_variable_set( :@log, options[:log] ) unless options[:log].nil?

      @plugins[info[:name]] = { :info => info, :plugin => plugin }

      self
    end

    attr_reader :plugins
  end
end
