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

require 'boxgrinder/appliance-kickstart.rb'
require 'boxgrinder/images/raw-image.rb'
require 'boxgrinder/images/vmware-image'
require 'boxgrinder/images/ec2-image'
require 'boxgrinder/helpers/release-helper'
require 'boxgrinder/validators/appliance-dependency-validator'

module BoxGrinder
  class Appliance < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config            = config
      @appliance_config  = appliance_config
      @log               = options[:log] || Logger.new(STDOUT)

      define
    end

    def define
      ApplianceKickstart.new( @config, @appliance_config, :log => @log )
      ApplianceDependencyValidator.new( @config, @appliance_config, :log => @log )

      RAWImage.new( @config, @appliance_config, :log => @log  )
      VMwareImage.new( @config, @appliance_config, :log => @log  )
      EC2Image.new( @config, @appliance_config, :log => @log )

      ReleaseHelper.new( @config, @appliance_config, :log => @log )
    end
  end
end
