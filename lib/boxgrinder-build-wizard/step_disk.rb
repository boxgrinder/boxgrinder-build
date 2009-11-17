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

require 'boxgrinder-build-wizard/step'

module JBossCloudWizard
  class StepDisk < Step
    def initialize(config)
      @config = config
    end

    def start
      ask_for_disk

      @config
    end

    def default_disk_size(appliance)
      if appliance == "meta-appliance"
        disk_size = 10
      else
        disk_size = 2
      end

      disk_size
    end

    def ask_for_disk

      disk_size = default_disk_size(@config.name)

      print "\n#{banner} How big should be the disk (in GB)? [#{disk_size}] "

      disk_size = gets.chomp

      ask_for_disk unless valid_disk_size?( disk_size )
    end

    def valid_disk_size?( disk_size )
      if (disk_size.length == 0)
        disk_size = default_disk_size(@config.name)
      end

      if disk_size.to_i == 0
        puts "\n    Sorry, '#{disk_size}' is not a valid value" unless disk_size.length == 0
        return false
      end

      min_disk_size = default_disk_size(@config.name)

      if (disk_size.to_i < min_disk_size)
        puts "\n    Sorry, #{disk_size}GB is not enough for #{@config.name}, please give >= #{min_disk_size}GB"
        return false
      end

      puts "\n    You have selected #{disk_size}GB disk"

      @config.disk_size = disk_size
      return true
    end

  end
end