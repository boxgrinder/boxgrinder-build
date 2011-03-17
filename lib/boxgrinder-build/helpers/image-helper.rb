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
