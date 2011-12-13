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
    plugin :type => :os, :name => :rhel, :full_name => "Red Hat Enterprise Linux", :versions => ['5', '6']

    def after_init
      super
      register_supported_os('rhel', ['5', '6'])
    end

    def build_rhel(appliance_definition_file, repos = {})
      normalize_packages(@appliance_config.packages)

      build_with_appliance_creator(appliance_definition_file, repos) do |guestfs, guestfs_helper|
        # required for VMware and KVM
        @linux_helper.recreate_kernel_image(guestfs, ['mptspi', 'virtio_pci', 'virtio_blk']) if @appliance_config.os.version == '5' and !@appliance_config.packages.include?('kernel-xen')
      end
    end

    def normalize_packages(packages)
      # https://issues.jboss.org/browse/BGBUILD-89
      add_packages(packages, ['@core', 'curl', 'grub'])

      case @appliance_config.os.version
        when '5'
          packages << 'kernel' unless packages.include?('kernel-xen')
          add_packages(packages, ['system-config-securitylevel-tui', 'util-linux', 'setarch', 'sudo'])
        when '6'
          add_packages(packages, ['kernel', 'system-config-firewall-base'])
      end
    end

    def add_packages(packages, package_array)
      package_array.each { |package| packages << package unless packages.include?(package) }
    end

    def execute(appliance_definition_file)
      build_rhel(appliance_definition_file)
    end
  end
end

