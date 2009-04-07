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

require 'jboss-cloud-wizard/step'
require 'jboss-cloud-support/defaults'

module JBossCloudWizard
  class StepAppliance < Step

    def initialize(appliances, arches)
      @appliances = appliances
      @arches = arches
    end

    def start
      ask_for_appliance
      ask_for_architecture

      config = JBossCloud::ApplianceConfig.new( @appliance, @arch, APPLIANCE_DEFAULTS['os_name'], APPLIANCE_DEFAULTS['os_version'] )
      config.vcpu = APPLIANCE_DEFAULTS['vcpu']

      config
    end

    def ask_for_architecture
      current_arch = (-1.size) == 8 ? "x86_64" : "i386"

      if current_arch == "i386"
        # puts "Current architecture is i386, you can build only 32bit appliances"
        @arch = "i386"
        return
      else

        list_architectures

        print "#{banner} Which architecture do you want to select? (1-#{@arches.size}) "

        arch = gets.chomp

        ask_for_architecture unless valid_architecture?(arch)
      end

    end

    def ask_for_appliance
      list_appliances

      print "#{banner} Which appliance do you want to build? (1-#{@appliances.size}) "

      appliance = gets.chomp

      ask_for_appliance unless valid_appliance?( appliance )
    end

    def list_architectures
      puts "\n#{banner} Available architectures:"

      i = 0

      puts
      @arches.each do |arch|
        puts "    #{i += 1}. " + arch
      end
      puts
    end

    def list_appliances
      puts "\n#{banner} Available appliances:"

      i = 0

      puts
      @appliances.each do |appliance|
        puts "    #{i += 1}. " + appliance
      end
      puts
    end

    def valid_appliance?(appliance)
      return false if appliance.to_i == 0 or appliance.length == 0

      appliance = appliance.to_i

      return false unless appliance >= 1 and appliance <= @appliances.size

      @appliance = @appliances[appliance - 1]
      puts "\n    You have selected #{@appliance}"

      return true
    end

    def valid_architecture?(arch)
      return false if arch.to_i == 0 or arch.length == 0

      arch = arch.to_i

      return false unless arch >= 1 and arch <= @arches.size

      @arch = @arches[arch - 1]
      puts "\n    You have selected #{@arch} architecture"

      return true
    end
  end
end
