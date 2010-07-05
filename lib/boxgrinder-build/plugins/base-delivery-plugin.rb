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

require 'boxgrinder-build/plugins/base-plugin'

module BoxGrinder
  class BaseDeliveryPlugin < BasePlugin
    alias_method :execute_original, :execute

    def execute( deliverables, type)
      raise "Delivery cannot be started before the plugin isn't initialized" if @initialized.nil?
      raise "Not valid delivery type selected for #{info[:name]} plugin: #{type}. Available types: #{info[:type].join(" ")}" unless info[:type].include?(type)
      
      execute_original( deliverables, type )
    end

    def already_delivered?
      false
    end
  end
end