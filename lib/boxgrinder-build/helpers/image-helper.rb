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

    def mount_image(disk, mount_dir)
      offsets = calculate_disk_offsets(disk)

      @log.debug "Mounting image #{File.basename(disk)} in #{mount_dir}..."
      FileUtils.mkdir_p(mount_dir)

      mounts = {}

      offsets.each do |offset|
        loop_device = get_loop_device
        @exec_helper.execute("losetup -o #{offset.to_s} #{loop_device} '#{disk}'")
        label = @exec_helper.execute("e2label #{loop_device}").strip.chomp.gsub('_', '')
        label = '/' if label == ''
        mounts[label] = loop_device
      end

      @exec_helper.execute("mount #{mounts['/']} '#{mount_dir}'")

      mounts.reject { |key, value| key == '/' }.each do |mount_point, loop_device|
        @exec_helper.execute("mount #{loop_device} '#{mount_dir}#{mount_point}'")
      end

      @log.trace "Mounts:\n#{mounts}"

      mounts
    end

    def umount_image(disk, mount_dir, mounts)
      @log.debug "Unmounting image '#{File.basename(disk)}'..."

      mounts.each { |mount_point, loop_device| @exec_helper.execute("umount -d #{loop_device}") unless mount_point == '/' }

      @exec_helper.execute("umount -d #{mounts['/']}")

      FileUtils.rm_rf(mount_dir)
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

    def get_loop_device
      begin
        loop_device = @exec_helper.execute("losetup -f 2>&1").strip
      rescue
        raise "No free loop devices available, please free at least one. See 'losetup -d' command."
      end

      loop_device
    end

    def calculate_disk_offsets(disk)
      @log.debug "Calculating offsets for '#{File.basename(disk)}' disk..."
      loop_device = get_loop_device

      @exec_helper.execute("losetup #{loop_device} '#{disk}'")
      offsets = @exec_helper.execute("parted #{loop_device} 'unit B print' | grep -e '^ [0-9]' | awk '{ print $2 }'").scan(/\d+/)
      # wait one secont before freeing loop device
      sleep 1
      @exec_helper.execute("losetup -d #{loop_device}")

      @log.trace "Offsets:\n#{offsets}"

      offsets
    end

    def create_disk(disk, size)
      @log.trace "Preparing disk..."
      @exec_helper.execute "dd if=/dev/zero of='#{disk}' bs=1 count=0 seek=#{size * 1024}M"
      @log.trace "Disk prepared"
    end

    def create_filesystem(loop_device, options = {})
      options = {
          :type => @appliance_config.hardware.partitions['/']['type'],
          :label => '/'
      }.merge(options)

      @log.trace "Creating filesystem..."

      case options[:type]
        when 'ext3', 'ext4'
          @exec_helper.execute "mke2fs -T #{options[:type]} -L '#{options[:label]}' -F #{loop_device}"
        else
          raise "Unsupported filesystem specified: #{options[:type]}"
      end

      @log.trace "Filesystem created"
    end

    def sync_files(from_dir, to_dir)
      @log.debug "Syncing files between #{from_dir} and #{to_dir}..."
      @exec_helper.execute "rsync -Xura #{from_dir.gsub(' ', '\ ')}/* '#{to_dir}'"
      @log.debug "Sync finished."
    end

    def customize(disk_path)
      GuestFSHelper.new(disk_path, :log => @log).customize(:ide_disk => ((@appliance_config.os.name == 'rhel' or @appliance_config.os.name == 'centos') and @appliance_config.os.version == '5') ? true : false) do |guestfs, guestfs_helper|
        yield guestfs, guestfs_helper
      end
    end
  end
end
