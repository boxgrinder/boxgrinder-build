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
  class StepMemory < Step
    def initialize(config)
      @config = config
    end

    def start
      ask_for_memory

      @config
    end

    def minimum_mem_size(appliance)
      # Minimal amount of RAM for appliances:
      # meta-appliance            - 512
      # jboss-as5-appliance       - 512
      # postgis-appliance         - 256
      # httpd-appliance           - 256
      # jboss-jgroups-appliance   - 256

      if appliance == "postgis-appliance" or appliance == "httpd-appliance" or appliance == "jboss-jgroups-appliance"
        mem_size = 256
      else
        mem_size = 512
      end

      mem_size
    end

    def default_mem_size(appliance)
      if appliance == "postgis-appliance" or appliance == "httpd-appliance" or appliance == "jboss-jgroups-appliance"
        mem_size = 512
      else
        mem_size = 1024
      end

      mem_size
    end

    def ask_for_memory
      mem_size = default_mem_size(@config.name)

      print "\n#{banner} How much RAM do you want (in MB)? [#{mem_size}] "

      mem_size = gets.chomp

      ask_for_memory unless valid_mem_size?( mem_size )
    end

    def valid_mem_size?( mem_size )
      if (mem_size.length == 0)
        mem_size = default_mem_size(@config.name)
      end

      if mem_size.to_i == 0
        puts "\n    Sorry, '#{mem_size}' is not a valid value"
        return false
      end

      min_mem_size = minimum_mem_size(@config.name)

      if (mem_size.to_i % 128 > 0)
        puts "\n    Memory size should be multiplicity of 128MB"
        return false
      end

      if (mem_size.to_i < min_mem_size)
        puts "\n    Sorry, #{mem_size}MB is not enough for #{@config.name}, please give >= #{min_mem_size}MB"
        return false
      end

      puts "\n    You have selected #{mem_size}MB memory"

      @config.mem_size = mem_size
      return true
    end

  end
end