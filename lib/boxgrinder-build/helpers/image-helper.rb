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

require 'fileutils'
require 'boxgrinder-core/helpers/log-helper'
require 'boxgrinder-build/helpers/guestfs-helper'

module BoxGrinder
  class ImageHelper
    def initialize(config, appliance_config, options = {})
      @config = config
      @appliance_config = appliance_config

      @log = options[:log] || LogHelper.new
      @exec_helper = options[:exec_helper] || ExecHelper.new(:log => @log)
    end

    def disk_info(disk)
      YAML.load(@exec_helper.execute("qemu-img info '#{disk}'"))
    end

    def convert_disk(disk, format, destination)
      @log.debug "Conveting '#{disk}' disk to #{format} format and moving it to '#{destination}'..."

      unless File.exists?(destination)
        info = disk_info(disk)

        if info['file format'] == format.to_s
          @exec_helper.execute "cp '#{disk}' '#{destination}'"
        else

          format_with_options = format.to_s

          if format == :vmdk
            format_with_options += (`qemu-img --help | grep '\\-6'`.strip.chomp.empty? ? ' -o compat6' : ' -6')
          end

          @exec_helper.execute "qemu-img convert -f #{info['file format']} -O #{format_with_options} '#{disk}' '#{destination}'"
        end
      else
        @log.debug "Destination already exists, skipping disk conversion."
      end
    end

    # Synchronizes filesystem from one image with an empty disk image.
    # Input image can be a partioned image or a partition image itself.
    # Output disk is a partition image.
    #
    # See also https://bugzilla.redhat.com/show_bug.cgi?id=690819
    #
    def sync_filesystem(guestfs, guestfs_helper)
      devices = guestfs.list_devices
      in_device = devices.first
      out_device = devices.last
      partitions = guestfs.list_partitions.reject { |i| !(i =~ /^#{in_device}/) }

      @log.debug "Loading SELinux policy to sync filesystem..."
      partitions.size > 0 ? guestfs_helper.mount_partitions(in_device) : guestfs_helper.mount_partition(in_device, '/')
      guestfs_helper.load_selinux_policy
      partitions.size > 0 ? guestfs_helper.umount_partitions(in_device) : guestfs_helper.umount_partition(in_device)
      @log.debug "SELinux policy was loaded, we're ready to sync filesystem."

      @log.info "Synchronizing filesystems..."

      # Create mount points in libguestfs
      guestfs.mkmountpoint('/in')
      guestfs.mkmountpoint('/out')
      guestfs.mkmountpoint('/out/in')

      # Create filesystem on EC2 disk
      guestfs.mkfs(@appliance_config.default_filesystem_type, out_device)
      # Set root partition label
      guestfs.set_e2label(out_device, '79d3d2d4') # This is a CRC32 from /

      # Mount empty EC2 disk to /out
      guestfs_helper.mount_partition(out_device, '/out/in')
      partitions.size > 0 ? guestfs_helper.mount_partitions(in_device, '/in') : guestfs_helper.mount_partition(in_device, '/in')

      @log.debug "Copying files..."

      # Copy the filesystem
      guestfs.cp_a('/in/', '/out')

      @log.debug "Files copied."

      # Better make sure...
      guestfs.sync

      guestfs_helper.umount_partition(out_device)
      partitions.size > 0 ? guestfs_helper.umount_partitions(in_device) : guestfs_helper.umount_partition(in_device)

      guestfs.rmmountpoint('/out/in')
      guestfs.rmmountpoint('/out')
      guestfs.rmmountpoint('/in')

      @log.info "Filesystems synchronized."

      # Remount the destination disk
      guestfs_helper.mount_partition(out_device, '/')
    end

    def create_disk(disk, size)
      @log.trace "Preparing disk..."
      @exec_helper.execute "dd if=/dev/zero of='#{disk}' bs=1 count=0 seek=#{(size * 1024).to_i}M"
      @log.trace "Disk prepared"
    end

    def customize(disks, options = {})
      options = {
          :ide_disk => ((@appliance_config.os.name == 'rhel' or @appliance_config.os.name == 'centos') and @appliance_config.os.version == '5') ? true : false
      }.merge(options)

      GuestFSHelper.new(disks, @appliance_config, @config, :log => @log).customize(options) do |guestfs, guestfs_helper|
        yield guestfs, guestfs_helper
      end
    end
  end
end
