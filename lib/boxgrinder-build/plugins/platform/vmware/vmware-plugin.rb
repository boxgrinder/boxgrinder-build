# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
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

require 'boxgrinder-build/plugins/platform/base-platform-plugin'
require 'boxgrinder-build/helpers/appliance-customize-helper'

module BoxGrinder
  class VMwarePlugin < BasePlatformPlugin
    def info
      {
              :name       => :vmware,
              :full_name  => "VMware"
      }
    end

    def after_init
      @deliverables[:disk] = "#{@appliance_config.path.dir.build}/vmware/#{@appliance_config.name}.raw"

      @deliverables[:metadata]  = {
              :vmx_enterprise   => "#{@appliance_config.path.dir.build}/vmware/#{@appliance_config.name}-enterprise.vmx",
              :vmdk_enterprise  => "#{@appliance_config.path.dir.build}/vmware/#{@appliance_config.name}-enterprise.vmdk",
              :vmx_personal     => "#{@appliance_config.path.dir.build}/vmware/#{@appliance_config.name}-personal.vmx",
              :vmdk_personal    => "#{@appliance_config.path.dir.build}/vmware/#{@appliance_config.name}-personal.vmdk"
      }

      @deliverables[:other]     = {
              :readme           => "#{@appliance_config.path.dir.build}/vmware/README"
      }
    end


    def execute( base_image_path )
      @log.info "Converting image to VMware format..."
      @log.debug "Copying VMware image file, this may take several minutes..."

      FileUtils.mkdir_p File.dirname( @deliverables[:disk] )

      @exec_helper.execute "cp #{base_image_path} #{@deliverables[:disk]}" if ( !File.exists?( @deliverables[:disk] ) || File.new( base_image_path ).mtime > File.new( @deliverables[:disk] ).mtime )

      @log.debug "VMware image copied."

      if @appliance_config.post.vmware.size > 0
        customize( @deliverables[:disk] ) do |guestfs, guestfs_helper|
          @appliance_config.post.vmware.each do |cmd|
            @log.debug "Executing #{cmd}"
            guestfs.sh( cmd )
          end
          @log.debug "Post commands from appliance definition file executed."
        end
      else
        @log.debug "No commands specified, skipping."
      end

      build_vmware_enterprise
      build_vmware_personal

      readme = File.open( "#{File.dirname(__FILE__)}/src/README" ).read
      readme.gsub!( /#APPLIANCE_NAME#/, @appliance_config.name )
      readme.gsub!( /#NAME#/, @config.name )
      readme.gsub!( /#VERSION#/, @config.version_with_release )

      File.open( @deliverables[:other][:readme], "w") {|f| f.write( readme ) }

      @log.info "Image converted to VMware format."
    end

    # returns value of cylinders, heads and sector for selected disk size (in GB)

    def generate_scsi_chs(disk_size)
      disk_size = (disk_size * 1024).to_i

      gb_sectors = 2097152

      if disk_size <= 1024
        h = 128
        s = 32
      else
        h = 255
        s = 63
      end

      c = disk_size / 1024 * gb_sectors / (h*s)
      total_sectors = gb_sectors * disk_size / 1024

      return [ c, h, s, total_sectors ]
    end

    def change_vmdk_values( type )
      vmdk_data = File.open( "#{File.dirname( __FILE__ )}/src/base.vmdk" ).read

      disk_size = 0.0
      @appliance_config.hardware.partitions.values.each { |part| disk_size += part['size'].to_f }

      c, h, s, total_sectors = generate_scsi_chs( disk_size )

      is_enterprise = type.eql?("vmfs")

      vmdk_data.gsub!( /#NAME#/, @appliance_config.name )
      vmdk_data.gsub!( /#TYPE#/, type )
      vmdk_data.gsub!( /#EXTENT_TYPE#/, is_enterprise ? "VMFS" : "FLAT" )
      vmdk_data.gsub!( /#NUMBER#/, is_enterprise ? "" : "0" )
      vmdk_data.gsub!( /#HW_VERSION#/, is_enterprise ? "4" : "3" )
      vmdk_data.gsub!( /#CYLINDERS#/, c.to_s )
      vmdk_data.gsub!( /#HEADS#/, h.to_s )
      vmdk_data.gsub!( /#SECTORS#/, s.to_s )
      vmdk_data.gsub!( /#TOTAL_SECTORS#/, total_sectors.to_s )

      vmdk_data
    end

    def change_common_vmx_values
      vmx_data = File.open( "#{File.dirname( __FILE__ )}/src/base.vmx" ).read

      # replace version with current appliance version
      vmx_data.gsub!( /#VERSION#/, "#{@appliance_config.version}.#{@appliance_config.release}" )
      # replace builder with current builder name and version
      vmx_data.gsub!( /#BUILDER#/, "#{@config.name} #{@config.version_with_release}" )
      # change name
      vmx_data.gsub!( /#NAME#/, @appliance_config.name.to_s )
      # and summary
      vmx_data.gsub!( /#SUMMARY#/, @appliance_config.summary.to_s )
      # replace guestOS informations to: linux or otherlinux-64, this seems to be the savests values
      vmx_data.gsub!( /#GUESTOS#/, "#{@appliance_config.hardware.arch == "x86_64" ? "otherlinux-64" : "linux"}" )
      # memory size
      vmx_data.gsub!( /#MEM_SIZE#/, @appliance_config.hardware.memory.to_s )
      # memory size
      vmx_data.gsub!( /#VCPU#/, @appliance_config.hardware.cpus.to_s )
      # network name
      # vmx_data.gsub!( /#NETWORK_NAME#/, @image_config.network_name )

      vmx_data
    end

    def build_vmware_personal
      @log.debug "Building VMware personal image."

      # create .vmx file
      File.open( @deliverables[:metadata][:vmx_personal], "w" ) {|f| f.write( change_common_vmx_values ) }

      # create disk descriptor file
      File.open( @deliverables[:metadata][:vmdk_personal], "w" ) {|f| f.write( change_vmdk_values( "monolithicFlat" ) ) }

      @log.debug "VMware personal image was built."
    end

    def build_vmware_enterprise
      @log.debug "Building VMware enterprise image."

      # defaults for ESXi (maybe for others too)
      @appliance_config.hardware.network = "VM Network" if @appliance_config.hardware.network.eql?( "NAT" )

      # create .vmx file
      vmx_data = change_common_vmx_values
      vmx_data += "ethernet0.networkName = \"#{@appliance_config.hardware.network}\""

      File.open( @deliverables[:metadata][:vmx_enterprise], "w" ) {|f| f.write( vmx_data ) }

      # create disk descriptor file
      File.open( @deliverables[:metadata][:vmdk_enterprise], "w" ) {|f| f.write( change_vmdk_values( "vmfs" ) ) }

      @log.debug "VMware enterprise image was built."
    end
  end
end