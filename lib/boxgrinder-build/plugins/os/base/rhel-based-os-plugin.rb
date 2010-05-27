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

require 'boxgrinder-build/plugins/os/base/rpm-based-os-plugin'

module BoxGrinder
  class RHELBasedOSPlugin < RPMBasedOSPlugin
    def build_rhel( repos = {} )
      adjust_partition_table

      disk_path = build_with_appliance_creator( repos )  do |guestfs, guestfs_helper|
        kernel_version = guestfs.ls("/lib/modules").first

        @log.debug "Recreating initrd for #{kernel_version} kernel..."
        guestfs.sh( "/sbin/mkinitrd -f -v --preload=mptspi /boot/initrd-#{kernel_version}.img #{kernel_version}" )
        @log.debug "Initrd recreated."

        @log.debug "Applying root password..."
        guestfs.sh( "/usr/bin/passwd -d root" )
        guestfs.sh( "/usr/sbin/usermod -p '#{@appliance_config.os.password.crypt((0...8).map{65.+(rand(25)).chr}.join)}' root" )
        @log.debug "Password applied."
      end

      @log.info "Done."

      disk_path
    end

    # https://bugzilla.redhat.com/show_bug.cgi?id=466275
    def adjust_partition_table
      @appliance_config.hardware.partitions['/boot'] = { 'root' => '/boot', 'size' => 0.1 } if @appliance_config.hardware.partitions['/boot'].nil?
    end
  end
end