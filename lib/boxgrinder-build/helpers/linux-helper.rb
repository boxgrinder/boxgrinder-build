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

require 'boxgrinder-core/helpers/log-helper'

module BoxGrinder

  # A class tha helps dealing with RPM version numbers
  #
  class RPMVersion
    def split(version)
      version_array = []

      version.split('-').each do |v|
        v.split('.').each { |nb| version_array << nb }
      end

      version_array
    end

    def compare(v1, v2)
      s1 = split(v1)
      s2 = split(v2)

      for i in (0..s1.size-1)
        cmp = (s1[i].to_i <=> s2[i].to_i)
        return cmp unless cmp == 0
      end

      0
    end

    # Returns newest version from the array
    #
    def newest(versions)
      versions.sort { |x,y| compare(x,y) }.last
    end
  end

  class LinuxHelper
    def initialize(options = {})
      @log = options[:log] || LogHelper.new
    end

    # Returns valid array of sorted mount points
    #
    # ['/', '/home'] => ['/', '/home']
    # ['swap', '/', '/home'] => ['/', '/home', 'swap']
    # ['swap', '/', '/home', '/boot'] => ['/', '/boot', '/home', 'swap']
    # ['/tmp-eventlog', '/', '/ubrc', '/tmp-config'] => ['/', '/ubrc', '/tmp-config', '/tmp-eventlog']
    #
    def partition_mount_points(partitions)
      partitions.keys.sort do |a, b|
        a_count = a.count('/')
        b_count = b.count('/')

        if a_count > b_count
          v = 1
        else
          if a_count < b_count
            v = -1
          else
            if a.length == b.length
              v = a <=> b
            else
              v = a.length <=> b.length
            end
          end
        end

        # This forces having swap partition at the end of the disk
        v = 1 if a_count == 0
        v = -1 if b_count == 0

        v
      end
    end

    def kernel_version(guestfs)
      kernel_versions = guestfs.ls("/lib/modules")

      # By default use the latest available kernel...
      version = RPMVersion.new.newest(kernel_versions)

      # ...but prefer xen or PAE kernel over others
      if kernel_versions.size > 1
        kernel_versions.each do |v|
          if v.match(/xen$/) or v.match(/PAE$/)
            version = v
            break
          end
        end
      end

      version
    end

    def kernel_image_name(guestfs)
      guestfs.sh("ls -1 /boot | grep initramfs | wc -l").chomp.strip.to_i > 0 ? "initramfs" : "initrd"
    end

    def recreate_kernel_image(guestfs, modules = [])
      kernel_version = kernel_version(guestfs)

      raise "Cannot find valid kernel installs in the appliance. Make sure you have your kernel installed in '/lib/modules'." if kernel_version.nil?

      kernel_image_name = kernel_image_name(guestfs)

      if guestfs.exists("/sbin/dracut") != 0
        command = "/sbin/dracut -f -v --add-drivers #{modules.join(' ')}"
      else
        drivers_argument = ""
        modules.each { |mod| drivers_argument << " --preload=#{mod}" }

        command = "/sbin/mkinitrd -f -v#{drivers_argument}"
      end

      @log.trace "Additional modules to preload in kernel: #{modules.join(', ')}"

      @log.debug "Recreating kernel image for #{kernel_version} kernel..."
      guestfs.sh("#{command} /boot/#{kernel_image_name}-#{kernel_version}.img #{kernel_version}")
      @log.debug "Kernel image recreated."
    end

    def packages_providing(guestfs, capability)
      guestfs.sh("rpm -q --whatprovides #{capability}").split("\n")
    end

    def package_name(guestfs, package)
      guestfs.sh("rpm -q --qf='%{name}' #{package}")
    end
  end
end
