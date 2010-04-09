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

require 'rake/tasklib'

require 'boxgrinder-build/helpers/release-helper'
require 'boxgrinder-build/validators/appliance-dependency-validator'

module BoxGrinder
  class Appliance < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config            = config
      @appliance_config  = appliance_config
      @log               = options[:log] || Logger.new(STDOUT)

      define
    end

    def define
      # TODO this needs to be rewritten
      #ApplianceDependencyValidator.new( @config, @appliance_config, :log => @log )

      desc "Build #{@appliance_config.simple_name} appliance."
      task "appliance:#{@appliance_config.name}" => [ @appliance_config.path.file.raw.xml ]

      # "appliance:#{@appliance_config.name}:validate:dependencies"

      file @appliance_config.path.file.raw.xml do
        OperatingSystemPluginManager.instance.plugins[@appliance_config.os.name.to_sym].build( @config, @appliance_config, :log => @log )
      end

      PlatformPluginManager.instance.plugins.each_value do |plugin|
        plugin.define( @config, @appliance_config, :log => @log )
      end

      #ReleaseHelper.new( @config, @appliance_config, :log => @log )
    end
  end
end
