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

require 'boxgrinder-build/plugins/os/base-operating-system-plugin'

module BoxGrinder
  class RPMBasedOSPlugin < BaseOperatingSystemPlugin

    def build_with_appliance_creator( repos )
      Kickstart.new( @config, @appliance_config, repos, :log => @log ).create
      RPMDependencyValidator.new( @config, @appliance_config, @options ).resolve_packages

      tmp_dir = "#{@config.dir.root}/#{@config.dir.build}/tmp"

      FileUtils.mkdir_p( tmp_dir )

      disk_type = 'sda'
      disk_path = "#{@appliance_config.path.dir.raw.build_full}/#{@appliance_config.name}-#{disk_type}.raw"

      @log.info "Building #{@appliance_config.simple_name} appliance..."

      @exec_helper.execute "sudo appliance-creator -d -v -t #{tmp_dir} --cache=#{@config.dir.rpms_cache}/#{@appliance_config.main_path} --config #{@appliance_config.path.file.raw.kickstart} -o #{@appliance_config.path.dir.raw.build} --name #{@appliance_config.name} --vmem #{@appliance_config.hardware.memory} --vcpu #{@appliance_config.hardware.cpus}"

      # fix permissions
      @exec_helper.execute "sudo chmod 777 #{@appliance_config.path.dir.raw.build_full}"
      @exec_helper.execute "sudo chmod 666 #{disk_path}"
      @exec_helper.execute "sudo chmod 666 #{@appliance_config.path.file.raw.xml}"

      @log.info "Appliance #{@appliance_config.simple_name} was built successfully."

      disk_path
    end
  end
end
