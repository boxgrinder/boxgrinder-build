#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
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

require 'boxgrinder-build/plugins/os/rpm-based/rpm-based-os-plugin'

module BoxGrinder
  class RHELPlugin < RPMBasedOSPlugin
    def after_init
      super
      register_supported_os('rhel', ['5', '6'])
    end

    def build_rhel(appliance_definition_file, repos = {})
      adjust_partition_table

      normalize_packages(@appliance_config.packages)

      build_with_appliance_creator(appliance_definition_file, repos) do |guestfs, guestfs_helper|
        # required for VMware and KVM
        @linux_helper.recreate_kernel_image(guestfs, ['mptspi', 'virtio_pci', 'virtio_blk']) if @appliance_config.os.version == '5' and !@appliance_config.packages.include?('kernel-xen')
      end
    end

    def normalize_packages(packages)
      # https://issues.jboss.org/browse/BGBUILD-89
      packages << '@core'
      packages << 'curl'

      case @appliance_config.os.version
        when '5'
          packages << "kernel" unless packages.include?("kernel") or packages.include?("kernel-xen")
          packages << "system-config-securitylevel-tui" unless packages.include?("system-config-securitylevel-tui")
          packages << 'util-linux' unless packages.include?('util-linux')
        when '6'
          packages << "kernel" unless packages.include?("kernel")
          packages << "system-config-firewall-base" unless packages.include?("system-config-firewall-base")
      end
    end

    # https://bugzilla.redhat.com/show_bug.cgi?id=466275
    def adjust_partition_table
      @appliance_config.hardware.partitions['/boot'] = {'root' => '/boot', 'type' => 'ext3', 'size' => 0.1} if @appliance_config.hardware.partitions['/boot'].nil?
    end

    def execute(appliance_definition_file)
      build_rhel(appliance_definition_file)
    end
  end
end
