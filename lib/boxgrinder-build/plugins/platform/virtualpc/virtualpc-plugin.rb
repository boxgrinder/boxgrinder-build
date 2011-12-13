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

module BoxGrinder
  class VirtualPCPlugin < BasePlugin
    plugin :type => :platform, :name => :virtualpc, :full_name => "VirtualPC"

    def after_init
      register_deliverable(:disk => "#{@appliance_config.name}.vhd")
    end

    def execute
      @log.info "Converting image to VirtualPC format..."

      convert
      customize_image

      @log.info "Image converted to VirtualPC format."
    end

    def customize_image
      unless @appliance_config.post['virtualpc'].nil? or @appliance_config.post['virtualpc'].empty?
        @image_helper.customize(@deliverables.disk) do |guestfs, guestfs_helper|
          @appliance_config.post['virtualpc'].each do |cmd|
            guestfs_helper.sh(cmd, :arch => @appliance_config.hardware.arch)
          end
          @log.debug "Post commands from appliance definition file executed."
        end
      else
        @log.debug "No commands specified, skipping."
      end
    end

    def convert
      @log.debug "Using qemu-img to convert the image..."
      @image_helper.convert_disk(@previous_deliverables.disk, :vpc, @deliverables.disk)
      @log.debug "Conversion done."
    end
  end
end

