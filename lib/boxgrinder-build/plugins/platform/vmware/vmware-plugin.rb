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
require 'boxgrinder-build/helpers/appliance-customize-helper'

module BoxGrinder
  class VMwarePlugin < BasePlugin
    def after_init
      set_default_config_value('thin_disk', false)
      validate_plugin_config(['type'], 'http://community.jboss.org/docs/DOC-15528')

      register_deliverable(:vmx    => "#{@appliance_config.name}.vmx",
                           :readme => "README")

      if @plugin_config['type'].eql?('personal') and @plugin_config['thin_disk']
        register_deliverable(:disk => "#{@appliance_config.name}.vmdk")
      else
        register_deliverable(:disk => "#{@appliance_config.name}.raw",
                             :vmdk => "#{@appliance_config.name}.vmdk")
      end
    end

    def execute
      @log.info "Converting image to VMware #{@plugin_config['type']} format..."

      case @plugin_config['type']
        when 'personal'
          build_vmware_personal
        when 'enterprise'
          build_vmware_enterprise
        else
          raise "Not known VMware format specified. Available are: personal and enterprise. See http://community.jboss.org/docs/DOC-15528 for more info."
      end

      customize_image

      File.open(@deliverables.readme, "w") { |f| f.write(create_readme) }

      @log.info "Image converted to VMware format."
    end

    def create_readme
      readme = File.open("#{File.dirname(__FILE__)}/src/README-#{@plugin_config['type']}").read
      readme.gsub!(/#APPLIANCE_NAME#/, @appliance_config.name)

      readme
    end

    # returns value of cylinders, heads and sector for selected disk size (in GB)
    # http://kb.vmware.com/kb/1026254
    def generate_scsi_chs(disk_size)
      if disk_size < 1
        h = 64
        s = 32
      else
        if disk_size < 2
          h = 128
          s = 32
        else
          h = 255
          s = 63
        end
      end

      #               GB          MB     KB     B
      c             = disk_size * 1024 * 1024 * 1024 / (h*s*512)
      total_sectors = disk_size * 1024 * 1024 * 1024 / 512

      [c.to_i, h.to_i, s.to_i, total_sectors.to_i]
    end

    def change_vmdk_values(type)
      vmdk_data = File.open("#{File.dirname(__FILE__)}/src/base.vmdk").read

      disk_size = 0.0
      @appliance_config.hardware.partitions.values.each { |part| disk_size += part['size'].to_f }

      c, h, s, total_sectors = generate_scsi_chs(disk_size)

      is_enterprise = type.eql?("vmfs")

      vmdk_data.gsub!(/#NAME#/, @appliance_config.name)
      vmdk_data.gsub!(/#TYPE#/, type)
      vmdk_data.gsub!(/#EXTENT_TYPE#/, is_enterprise ? "VMFS" : "FLAT")
      vmdk_data.gsub!(/#NUMBER#/, is_enterprise ? "" : "0")
      vmdk_data.gsub!(/#HW_VERSION#/, "7")
      vmdk_data.gsub!(/#CYLINDERS#/, c.to_s)
      vmdk_data.gsub!(/#HEADS#/, h.to_s)
      vmdk_data.gsub!(/#SECTORS#/, s.to_s)
      vmdk_data.gsub!(/#TOTAL_SECTORS#/, total_sectors.to_s)
      vmdk_data.gsub!(/#THIN_PROVISIONED#/, @plugin_config['thin_disk'] ? "1" : "0")

      vmdk_data
    end

    def change_common_vmx_values
      vmx_data = File.open("#{File.dirname(__FILE__)}/src/base.vmx").read

      # replace version with current appliance version
      vmx_data.gsub!(/#VERSION#/, "#{@appliance_config.version}.#{@appliance_config.release}")
      # change name
      vmx_data.gsub!(/#NAME#/, @appliance_config.name.to_s)
      # and summary
      vmx_data.gsub!(/#SUMMARY#/, @appliance_config.summary.to_s)
      # replace guestOS informations to: linux or otherlinux-64, this seems to be the savests values
      vmx_data.gsub!(/#GUESTOS#/, "#{@appliance_config.hardware.arch == "x86_64" ? "otherlinux-64" : "linux"}")
      # memory size
      vmx_data.gsub!(/#MEM_SIZE#/, @appliance_config.hardware.memory.to_s)
      # memory size
      vmx_data.gsub!(/#VCPU#/, @appliance_config.hardware.cpus.to_s)
      # network name
      # vmx_data.gsub!( /#NETWORK_NAME#/, @image_config.network_name )

      vmx_data
    end

    def customize_image
      unless @appliance_config.post['vmware'].nil? or @appliance_config.post['vmware'].empty?
        @image_helper.customize(@deliverables.disk) do |guestfs, guestfs_helper|
          @appliance_config.post['vmware'].each do |cmd|
            guestfs_helper.sh(cmd, :arch => @appliance_config.hardware.arch)
          end
          @log.debug "Post commands from appliance definition file executed."
        end
      else
        @log.debug "No commands specified, skipping."
      end
    end

    def copy_raw_image
      @log.debug "Copying VMware image file, this may take several minutes..."
      @exec_helper.execute "cp '#{@previous_deliverables.disk}' '#{@deliverables.disk}'"
      @log.debug "VMware image copied."
    end

    def build_vmware_personal
      @log.debug "Building VMware personal image."

      if @plugin_config['thin_disk']
        @log.debug "Using qemu-img to convert the image..."
        @image_helper.convert_disk(@previous_deliverables.disk, :vmdk, @deliverables.disk)
        @log.debug "Conversion done."
      else
        copy_raw_image

        # create disk descriptor file
        File.open(@deliverables.vmdk, "w") { |f| f.write(change_vmdk_values("monolithicFlat")) }
      end

      # create .vmx file
      File.open(@deliverables.vmx, "w") { |f| f.write(change_common_vmx_values) }

      @log.debug "VMware personal image was built."
    end

    def build_vmware_enterprise
      @log.debug "Building VMware enterprise image."

      copy_raw_image

      # defaults for ESXi (maybe for others too)
      @appliance_config.hardware.network = "VM Network" if @appliance_config.hardware.network.eql?("NAT")

      # create .vmx file
      vmx_data = change_common_vmx_values
      vmx_data += "ethernet0.networkName = \"#{@appliance_config.hardware.network}\""

      File.open(@deliverables.vmx, "w") { |f| f.write(vmx_data) }

      # create disk descriptor file
      File.open(@deliverables.vmdk, "w") { |f| f.write(change_vmdk_values("vmfs")) }

      @log.debug "VMware enterprise image was built."
    end
  end
end
