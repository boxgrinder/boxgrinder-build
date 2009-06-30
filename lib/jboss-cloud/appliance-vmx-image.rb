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

require 'rake/tasklib'
require 'rexml/document'
require 'jboss-cloud/appliance-image-customize'

module JBossCloud

  class ApplianceVMXImage < Rake::TaskLib

    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config
      @log               = LOG

      @appliance_build_dir    = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @appliance_xml_file     = "#{@appliance_build_dir}/#{@appliance_config.name}.xml"
      @base_directory         = File.dirname( @appliance_xml_file )
      @base_raw_file          = "#{@base_directory}/#{@appliance_config.name}-sda.raw"
      @vmware_directory       = "#{@base_directory}/vmware"
      @base_vmware_raw_file   = "#{@vmware_directory}/#{@appliance_config.name}-sda.raw"

      @super_simple_name                    = File.basename( @appliance_config.name, '-appliance' )
      @vmware_personal_output_folder        = File.dirname( @appliance_xml_file ) + "/vmware/personal"
      @vmware_personal_vmx_file             = @vmware_personal_output_folder + "/" + @appliance_config.name + '.vmx'
      @vmware_personal_vmdk_file            = @vmware_personal_output_folder + "/" + @appliance_config.name + '.vmdk'
      @vmware_personal_raw_file             = @vmware_personal_output_folder + "/#{@appliance_config.name}-sda.raw"
      @vmware_enterprise_output_folder      = File.dirname( @appliance_xml_file ) + "/vmware/enterprise"
      @vmware_enterprise_vmx_file           = @vmware_enterprise_output_folder + "/" + @appliance_config.name + '.vmx'
      @vmware_enterprise_vmdk_file          = @vmware_enterprise_output_folder + "/" + @appliance_config.name + '.vmdk'
      @vmware_enterprise_raw_file           = @vmware_enterprise_output_folder + "/#{@appliance_config.name}-sda.raw"

      @appliance_image_customizer = ApplianceImageCustomize.new( @config, @appliance_config )

      define_tasks
    end

    def define_tasks
      directory @vmware_directory

      desc "Build #{@super_simple_name} appliance for VMware personal environments (Server/Workstation/Fusion)"
      task "appliance:#{@appliance_config.name}:vmware:personal" => [ @base_vmware_raw_file ] do
        build_vmware_personal
      end

      desc "Build #{@super_simple_name} appliance for VMware enterprise environments (ESX/ESXi)"
      task "appliance:#{@appliance_config.name}:vmware:enterprise" => [ @base_vmware_raw_file ] do
        build_vmware_enterprise
      end

      file @base_vmware_raw_file => [ @vmware_directory, @appliance_xml_file ] do
        create_base_vmware_raw_file
      end
    end
 
    # returns value of cylinders, heads and sector for selected disk size (in GB)

    def generate_scsi_chs(disk_size)
      disk_size =  disk_size * 1024

      gb_sectors = 2097152

      if disk_size == 1024
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
      vmdk_data = File.open( @config.files.base_vmdk ).read

      c, h, s, total_sectors = generate_scsi_chs( @appliance_config.disk_size )

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
      vmx_data = File.open( @config.files.base_vmx ).read

      # replace version with current jboss cloud version
      vmx_data.gsub!( /#VERSION#/, @config.version_with_release )
      # change name
      vmx_data.gsub!( /#NAME#/, @appliance_config.name )
      # and summary
      vmx_data.gsub!( /#SUMMARY#/, @appliance_config.summary )
      # replace guestOS informations to: linux or otherlinux-64, this seems to be the savests values
      vmx_data.gsub!( /#GUESTOS#/, "#{@appliance_config.arch == "x86_64" ? "otherlinux-64" : "linux"}" )
      # memory size
      vmx_data.gsub!( /#MEM_SIZE#/, @appliance_config.mem_size.to_s )
      # memory size
      vmx_data.gsub!( /#VCPU#/, @appliance_config.vcpu.to_s )
      # network name
      # vmx_data.gsub!( /#NETWORK_NAME#/, @appliance_config.network_name )

      vmx_data
    end

    def create_hardlink_to_disk_image( vmware_raw_file )
      # Hard link RAW disk to VMware destination folder
      FileUtils.ln( @base_vmware_raw_file, vmware_raw_file ) if ( !File.exists?( vmware_raw_file ) || File.new( @base_raw_file ).mtime > File.new( vmware_raw_file ).mtime )
    end

    def build_vmware_personal
      FileUtils.mkdir_p @vmware_personal_output_folder

      # link disk image
      create_hardlink_to_disk_image( @vmware_personal_raw_file )

      # create .vmx file
      File.open( @vmware_personal_vmx_file, "w" ) {|f| f.write( change_common_vmx_values ) }

      # create disk descriptor file
      File.open( @vmware_personal_vmdk_file, "w" ) {|f| f.write( change_vmdk_values( "monolithicFlat" ) ) }
    end

    def build_vmware_enterprise
      FileUtils.mkdir_p @vmware_enterprise_output_folder

      # link disk image
      create_hardlink_to_disk_image( @vmware_enterprise_raw_file )

      # defaults for ESXi (maybe for others too)
      @appliance_config.network_name = "VM Network" if @appliance_config.network_name.eql?( "NAT" )

      # create .vmx file
      vmx_data = change_common_vmx_values
      vmx_data += "ethernet0.networkName = \"#{@appliance_config.network_name}\""

      File.open( @vmware_enterprise_vmx_file, "w" ) {|f| f.write( vmx_data ) }

      # create disk descriptor file
      File.open( @vmware_enterprise_vmdk_file, "w" ) {|f| f.write( change_vmdk_values( "vmfs" ) ) }
    end

    def create_base_vmware_raw_file
      @log.info "Copying VMware image file, this may take several minutes..."

      FileUtils.cp( @base_raw_file, @base_vmware_raw_file ) if ( !File.exists?( @base_vmware_raw_file ) || File.new( @base_raw_file ).mtime > File.new( @base_vmware_raw_file ).mtime )

      @log.info "VMware image copied"
      @log.info "Installing VMware tools..."

      @appliance_image_customizer.customize( @base_vmware_raw_file, { :packages => { :rpm => [ "noarch/vm2-support-1.0.0.Beta1-1.noarch.rpm" ], :yum => [ "open-vm-tools" ] }, :repos => [ "http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-stable.noarch.rpm", "http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-stable.noarch.rpm" ] } )

      @log.info "VMware tools installed."
    end
  end
end
