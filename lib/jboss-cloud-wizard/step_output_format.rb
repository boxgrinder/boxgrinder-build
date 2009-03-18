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

module JBossCloudWizard
  class StepOutputFormat < Step
    def initialize(config, output_formats)
      @config = config
      @output_formats = output_formats
    end

    def start
      list_output_formats
      ask_for_output_format
      ask_for_network_name if is_vmware?

      @config
    end

    def is_vmware?
      return true if @config.output_format.to_i == 2 or @config.output_format.to_i == 3
      return false
    end

    def ask_for_network_name
      print "\n### Specify your network name [NAT] "

      network = gets.chomp

      # should be the best value
      if network.length == 0
        @config.network_name = "NAT"
      else
        @config.network_name = network
      end
    end

    def ask_for_output_format
      print "\n#{banner} Specify output format (1-#{@output_formats.size}) [1] "

      output_format = gets.chomp

      ask_for_output_format unless valid_output_format?( output_format )
    end

    def list_output_formats
      puts "\n#{banner} Available output formats:\r\n\r\n"

      i = 0

      @output_formats.each do |output_format|
        puts "    #{i += 1}. #{output_format}"
      end
    end

    def valid_output_format? ( output_format )
      # default - RAW
      if output_format.length == 0
        @config.output_format = 1
        return true
      end

      if output_format.to_i == 0
        puts "\n    Sorry, '#{output_format}' is not a valid value"
        return false
      end

      if output_format.to_i >= 1 and output_format.to_i <= @output_formats.size
        @config.output_format = output_format
        return true
      end

      return false
    end
   
  end
end