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

module JBossCloudWizard
  class BuildHelper
    def initialize( appliance_config, options )
      @appliance_config    = appliance_config
      @options             = options
      @dir_logs            = ENV['JBOSS_CLOUD_LOGS_DIR'] || "#{ENV['HOME']}/.jboss-cloud/wizard_logs"
    end

    def build( rake_task, msg_before, msg_success, msg_fail )
      build_time = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
      log_file_name = "#{@dir_logs}/wizard_#{build_time}"

      puts "\n    #{msg_before}"

      command = "JBOSS_CLOUD_DISK_SIZE=\"#{@appliance_config.disk_size}\" JBOSS_CLOUD_NETWORK_NAME=\"#{@appliance_config.network_name}\" JBOSS_CLOUD_ARCH=\"#{@appliance_config.arch}\" JBOSS_CLOUD_OS_NAME=\"#{@appliance_config.os_name}\" JBOSS_CLOUD_OS_VERSION=\"#{@appliance_config.os_version}\" JBOSS_CLOUD_VCPU=\"#{@appliance_config.vcpu}\" JBOSS_CLOUD_MEM_SIZE=\"#{@appliance_config.mem_size}\" #{rake_task}"

      unless execute( "#{command}", @options.verbose, log_file_name )
        puts "\n    #{msg_fail} Check log file: '#{log_file_name}'"
        exit(1)
      end

      puts "\n    #{msg_success}"
    end
  end
end