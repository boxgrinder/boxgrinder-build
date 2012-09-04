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

require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-build/helpers/linux-helper'

module BoxGrinder
  class VirtualBoxPlugin < BasePlugin
    plugin :type => :platform, :name => :virtualbox, :full_name => "VirtualBox"

    def after_init
      register_deliverable(:disk => "#{@appliance_config.name}.vmdk")
    end

    def execute
      @log.info "Converting image to VirtualBox format..."

      build_virtualbox

      if is_os_old? or !@appliance_config.post['virtualbox'].empty?
        @image_helper.customize([@deliverables.disk]) do |guestfs, guestfs_helper|
          recreate_kernel(guestfs) if is_os_old?
          customize(guestfs_helper) unless @appliance_config.post['virtualbox'].nil?
        end
      end

      @log.info "Image converted to VirtualBox format."
    end

    def is_os_old?
      (@appliance_config.os.name == 'centos' or @appliance_config.os.name == 'rhel') and @appliance_config.os.version == '5'
    end

    def build_virtualbox
      @log.debug "Building VirtualBox image."

      @log.debug "Using qemu-img to convert the image..."
      @image_helper.convert_disk(@previous_deliverables.disk, :vmdk, @deliverables.disk)
      @log.debug "Conversion done."

      @log.debug "VirtualBox image was built."
    end

    def recreate_kernel(guestfs)
      @log.info "Recreating kernel to include require modules..."
      LinuxHelper.new(:log => @log).recreate_kernel_image(guestfs, ['ahci'])
      @log.info "Kernel recreated."
    end

    def customize(guestfs_helper)
      @log.debug "Executing post commands from appliance definition..."
      @appliance_config.post['virtualbox'].each do |cmd|
        guestfs_helper.sh(cmd, :arch => @appliance_config.hardware.arch)
      end
      @log.debug "Post commands from appliance definition file executed."
    end
  end
end

