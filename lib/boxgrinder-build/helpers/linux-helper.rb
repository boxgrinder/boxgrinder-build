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
  class LinuxHelper
    def initialize(options = {})
      @log = options[:log] || LogHelper.new
    end

    # Returns valid array of sorted mount points
    #
    # ['/', '/home'] => ['/', '/home']
    # ['/tmp-eventlog', '/', '/ubrc', '/tmp-config'] => ['/', '/ubrc', '/tmp-config', '/tmp-eventlog']
    #
    def partition_mount_points(partitions)
      partitions.keys.sort do |a, b|
        if a.count('/') > b.count('/')
          v = 1
        else
          if a.count('/') < b.count('/')
            v = -1
          else
            v = a.length <=> b.length
          end
        end
        v
      end
    end

    def kernel_version(guestfs)
      kernel_versions = guestfs.ls("/lib/modules")
      version = kernel_versions.last

      if kernel_versions.size > 1
        kernel_versions.each do |v|
          if v.match(/PAE$/)
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
  end
end
