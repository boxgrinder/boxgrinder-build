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

require 'boxgrinder-build/managers/platform-plugin-manager'
require 'boxgrinder-build/plugins/base-plugin'

module BoxGrinder
  class BasePlatformPlugin < BasePlugin
    def self.inherited(klass)
      PlatformPluginManager.instance << klass
    end

    alias_method :execute_original, :execute

    def execute(args = nil)
      raise "Conversion cannot be started before the plugin isn't initialized" if @initialized.nil?
      execute_original(args)
    end
  end
end