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

      `mkdir -p #{mount_dir}`

      # TODO add progress bar
      @log.debug "Preparing disk for EC2 image..."
      @exec_helper.execute "dd if=/dev/zero of=#{@appliance_ec2_image_file} bs=1M count=#{10 * 1024}"
      @log.debug "Disk for EC2 image prepared"

      @log.debug "Creating filesystem..."
      @exec_helper.execute "mke2fs -Fj #{@appliance_ec2_image_file}"
      @log.debug "Filesystem created"

      @exec_helper.execute "sudo mount -o loop #{@appliance_ec2_image_file} #{mount_dir}"

      @log.debug "Syncing files between RAW and EC2 file..."
      loop_device = get_loop_device
      mount_image( loop_device, @appliance_raw_image )

      `sudo rsync -u -r -a  #{@mount_directory}/* #{mount_dir}`

      umount_image( loop_device, @appliance_raw_image )
      @log.debug "\nSyncing finished"

      # TODO rewrite this to use libguesfs
      `sudo mkdir -p #{mount_dir}/data`

      @log.debug "Creating required devices..."
      `sudo /sbin/MAKEDEV -d #{mount_dir}/dev -x console`
      `sudo /sbin/MAKEDEV -d #{mount_dir}/dev -x null`
      `sudo /sbin/MAKEDEV -d #{mount_dir}/dev -x zero`
      @log.debug "Devices created"

      fstab_data = "/dev/sda1  /         ext3    defaults         1 1\n"

      if @appliance_config.is64bit?
        fstab_data += "/dev/sdb   /mnt      ext3    defaults         0 0\n"
        fstab_data += "/dev/sdc   /data     ext3    defaults         0 0\n"
      else
        fstab_data += "/dev/sda2  /mnt      ext3    defaults         1 2\n"
        fstab_data += "/dev/sda3  swap      swap    defaults         0 0\n"
      end

      fstab_data += "none       /dev/pts  devpts  gid=5,mode=620   0 0\n"
      fstab_data += "none       /dev/shm  tmpfs   defaults         0 0\n"
      fstab_data += "none       /proc     proc    defaults         0 0\n"
      fstab_data += "none       /sys      sysfs   defaults         0 0\n"

      # Preparing /etc/fstab
      echo( "#{mount_dir}/etc/fstab", fstab_data )

      # enable networking on default runlevels
      `sudo chroot #{mount_dir} /sbin/chkconfig --level 345 network on`

      # enable DHCP
      echo( "#{mount_dir}/etc/sysconfig/network-scripts/ifcfg-eth0", "DEVICE=eth0\nBOOTPROTO=dhcp\nONBOOT=yes\nTYPE=Ethernet\nUSERCTL=yes\nPEERDNS=yes\nIPV6INIT=no\n" )

      #`sudo umount #{mount_dir}/proc`
      `sudo umount #{mount_dir}`
      `rm -rf #{mount_dir}`

      @log.debug "\nEC2 image prepared!"
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

      guesfs_helper = GuestFSHelper.new( raw_file )

      for repo in options[:repos]
        @log.debug "Installing repo file '#{repo}'..."
        guesfs_helper.guestfs.command( ["rpm", "-Uvh", repo] )
        @log.debug "Installed!"
      end

      for yum_package in options[:packages][:yum]
        @log.debug "Installing package #{yum_package}..."
        guesfs_helper.guestfs.command( ["yum", "-y", "install", yum_package] )
        @log.debug "Installed!"
      end unless options[:packages][:yum].nil?

      for package in options[:packages][:rpm]
        @log.debug "Installing package #{package}..."
        guesfs_helper.guestfs.command( ["rpm", "-Uvh", "--force", package] )
        @log.debug "Installed!"
      end unless options[:packages][:rpm].nil?

      guesfs_helper.guestfs.close
    end

    protected

    # TODO Remove this!
    def echo( file, content, append = false)
      `sudo chmod 777 #{file}`
      `sudo echo "#{content}" #{append ? ">>" : ">"} #{file}`
      `sudo chmod 664 #{file}`
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

      `sudo umount #{@mount_directory}`
      `sudo losetup -d #{loop_device}`

      FileUtils.rm_rf( @mount_directory )
    end

    # TODO: remove this!!!
    def install_gems( gems )
      return if gems.size == 0

      @log.info "Installing additional gems..."

      @exec_helper.execute( "sudo chroot #{@mount_directory} /bin/bash -c \"export HOME=/tmp && gem sources -r http://gems.github.com && gem sources -a http://gems.github.com && gem update --system > /dev/null && gem install #{gems.join(' ')} && gem list\"" )

      # TODO select a right place for this

      `sudo chroot #{@mount_directory} thin install`
      `sudo chroot #{@mount_directory} ln -s /usr/share/jboss-cloud-management/config/config.yaml /etc/thin/config.yaml`
      `sudo chroot #{@mount_directory} chkconfig --add thin`
      `sudo chroot #{@mount_directory} chkconfig --level 345 thin on`
    end
  end
end
