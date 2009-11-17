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
  class StepEC2 < Step
    def initialize( config, build_helper )
      @config       = config
      @build_helper = build_helper
    end

    def start
      list_additional_tasks
      ask_for_additional_task

      case @additional_task.to_i
      when 2
        @build_helper.build( "rake appliance:#{@config.name}:ec2:upload", "Uploading #{@config.simple_name} appliance to Amazon... (this may take a while)", "Appliance #{@config.simple_name} was successfully uploaded to Amazon.", "Uploading #{@config.simple_name} appliance to Amazon failed." )
      when 3
        # TODO add info about AMI number
        @build_helper.build( "rake appliance:#{@config.name}:ec2:register", "Registering #{@config.simple_name} appliance in Amazon... (this may take a while)", "Appliance #{@config.simple_name} was successfully registered in Amazon.", "Registering #{@config.simple_name} appliance in Amazon failed." )
      end
    end

    def list_additional_tasks
      puts "\n#{banner} Available additional tasks:\r\n\r\n"
      puts "    1. Do nothing"
      puts "    2. Upload to Amazon"
      puts "    3. Register as AMI (implies step 2)"
    end

    def ask_for_additional_task
      print "\n#{banner} What do you want to do with this EC2 image? (1-3) [1] "

      additional_task = gets.chomp

      ask_for_additional_task unless valid_additional_task?( additional_task )
    end

    def valid_additional_task?( additional_task )
      # default - RAW
      if additional_task.length == 0
        @additional_task = 1
        return true
      end

      if additional_task.to_i == 0
        puts "\n    Sorry, '#{additional_task}' is not a valid value"
        return false
      end

      if additional_task.to_i >= 1 and additional_task.to_i <= 3
        @additional_task = additional_task
        return true
      end

      return false
    end

  end
end