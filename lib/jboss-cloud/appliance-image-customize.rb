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
require 'jboss-cloud/validator/errors'
require 'jboss-cloud/helpers/guestfs-helper'

module JBossCloud
  class ApplianceImageCustomize < Rake::TaskLib

    def initialize( config, appliance_config, options = {}  )
      @config            = config
      @appliance_config  = appliance_config

      @log          = options[:log]         || LOG
      @exec_helper  = options[:exec_helper] || EXEC_HELPER

      @appliance_build_dir          = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @bundle_dir                   = "#{@appliance_build_dir}/ec2/bundle"
      @appliance_xml_file           = "#{@appliance_build_dir}/#{@appliance_config.name}.xml"
      @appliance_ec2_image_file     = "#{@appliance_build_dir}/#{@appliance_config.name}.ec2"
      @appliance_raw_image          = "#{@appliance_build_dir}/#{@appliance_config.name}-sda.raw"

      @mount_directory              = "#{@config.dir.build}/appliances/#{@config.build_path}/tmp/customize-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

    end

    def convert_to_ami
      mount_dir = "#{@config.dir.build}/appliances/#{@config.build_path}/tmp/ec2-image-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

      fstab_64bit     = "#{@config.dir.base}/src/ec2/fstab_64bit"
      fstab_32bit     = "#{@config.dir.base}/src/ec2/fstab_32bit"
      ifcfg_eth0      = "#{@config.dir.base}/src/ec2/ifcfg-eth0"
      rc_local_file   = "#{@config.dir.base}/src/ec2/rc_local"

      rpms = {
              AWS_DEFAULTS[:kernel_rpm][@appliance_config.arch].split("/").last => AWS_DEFAULTS[:kernel_rpm][@appliance_config.arch],
              "ec2-ami-tools.noarch.rpm" => "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm"
      }

      cache_rpms( rpms )

      # TODO add progress bar?
      @log.debug "Preparing disk for EC2 image..."
      @exec_helper.execute "dd if=/dev/zero of=#{@appliance_ec2_image_file} bs=1M count=#{10 * 1024}"
      @log.debug "Disk for EC2 image prepared"

      @log.debug "Creating filesystem..."
      @exec_helper.execute "mke2fs -Fj #{@appliance_ec2_image_file}"
      @log.debug "Filesystem created"

      `mkdir -p #{mount_dir}`

      @exec_helper.execute "sudo mount -o loop #{@appliance_ec2_image_file} #{mount_dir}"

      loop_device = get_loop_device
      mount_image( loop_device, @appliance_raw_image )

      @log.debug "Syncing files between RAW and EC2 file..."
      @exec_helper.execute "sudo rsync -u -r -a  #{@mount_directory}/* #{mount_dir}"
      @log.debug "Syncing finished"

      umount_image( loop_device, @appliance_raw_image )

      @exec_helper.execute "sudo umount -d #{mount_dir}"

      `rm -rf #{mount_dir}`

      guestfs = GuestFSHelper.new( @appliance_ec2_image_file ).guestfs

      @log.debug "Creating required devices..."
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x console" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x null" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x zero" )
      @log.debug "Devices created."

      @log.debug "Uploading '/etc/fstab' file..."
      fstab_file = @appliance_config.is64bit? ? fstab_64bit : fstab_32bit
      guestfs.upload( fstab_file, "/etc/fstab" )
      @log.debug "'/etc/fstab' file uploaded."

      # enable networking on default runlevels
      @log.debug "Enabling networking..."
      guestfs.sh( "/sbin/chkconfig --level 345 network on" )
      guestfs.upload( ifcfg_eth0, "/etc/sysconfig/network-scripts/ifcfg-eth0" )
      @log.debug "Networking enabled."

      @log.debug "Uploading '/etc/rc.local' file..."
      guestfs.upload( rc_local_file, "/etc/rc.local" )
      @log.debug "'/etc/rc.local' file uploaded."

      @log.debug "Installing additional packages (#{rpms.keys.join( ", " )})..."
      guestfs.mkdir_p("/tmp/rpms")

      for name in rpms.keys
        cache_file = "#{@config.dir_src_cache}/#{name}"
        guestfs.upload( cache_file, "/tmp/rpms/#{name}" )
      end

      guestfs.sh( "rpm -Uvh /tmp/rpms/*.rpm" )
      guestfs.rm_rf("/tmp/rpms")
      @log.debug "Additional packages installed."

      guestfs.close

      @log.debug "EC2 image prepared!"
    end

    def validate_options( options )
      options = {
              :packages => {},
              :repos => []
      }.merge(options)

      options[:packages][:yum]          = options[:packages][:yum]        || []
      options[:packages][:yum_local]    = options[:packages][:yum_local]  || []
      options[:packages][:rpm]          = options[:packages][:rpm]        || []

      if ( options[:packages][:yum_local].size == 0 and options[:packages][:rpm].size == 0 and options[:packages][:yum].size == 0 and options[:repos].size == 0)
        @log.debug "No additional local or remote packages or gems to install, skipping..."
        return false
      end

      true
    end

    def customize( raw_file, options = {} )
      # silent return, we don't have any packages to install
      return unless validate_options( options )

      raise ValidationError, "Raw file '#{raw_file}' doesn't exists, please specify valid raw file" if !File.exists?( raw_file )

      guestfs = GuestFSHelper.new( raw_file ).guestfs

      for repo in options[:repos]
        @log.debug "Installing repo file '#{repo}'..."
        guestfs.command( ["rpm", "-Uvh", repo] )
        @log.debug "Installed!"
      end unless options[:repos].nil?

      for yum_package in options[:packages][:yum]
        @log.debug "Installing package '#{yum_package}'..."
        guestfs.command( ["yum", "-y", "install", yum_package] )
        @log.debug "Installed!"
      end unless options[:packages][:yum].nil?

      for package in options[:packages][:rpm]
        @log.debug "Installing package '#{package}'..."
        guestfs.command( ["rpm", "-Uvh", "--force", package] )
        @log.debug "Installed!"
      end unless options[:packages][:rpm].nil?

      guestfs.close
    end

    protected

    def cache_rpms( rpms )
      for name in rpms.keys
        cache_file = "#{@config.dir_src_cache}/#{name}"

        if ( ! File.exist?( cache_file ) )
          FileUtils.mkdir_p( @config.dir_src_cache )
          @exec_helper.execute( "wget #{rpms[name]} -O #{cache_file}" )
        end
      end
    end

    def get_loop_device
      loop_device = `sudo losetup -f 2>&1`.strip

      if !loop_device.match( /^\/dev\/loop/ )
        raise "No free loop devices available, please free at least one. See 'losetup -d' command."
      end

      loop_device
    end

    def mount_image( loop_device, raw_file, offset = 32256 )
      @log.debug "Mounting image #{File.basename( raw_file )}"
      FileUtils.mkdir_p( @mount_directory )

      `sudo losetup -o #{offset.to_s} #{loop_device} #{raw_file}`
      `sudo mount #{loop_device} -t ext3 #{@mount_directory}`
    end

    def umount_image( loop_device, raw_file )
      @log.debug "Unmounting image #{File.basename( raw_file )}"

      `sudo umount -d #{@mount_directory}`
      `sudo losetup -d #{loop_device}`

      FileUtils.rm_rf( @mount_directory )
    end
  end
end
