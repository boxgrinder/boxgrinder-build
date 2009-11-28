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
require 'boxgrinder/validator/errors'
require 'boxgrinder/helpers/guestfs-helper'
require 'tempfile'

module BoxGrinder
  class ApplianceImageCustomize < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config = config
      @appliance_config = appliance_config

      @log = options[:log] || LOG
      @exec_helper = options[:exec_helper] || EXEC_HELPER

      @raw_file_mount_directory = "#{@config.dir.build}/#{@appliance_config.appliance_path}/tmp/raw-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

    end

    def convert_to_ami
      ec2_mount_dir = "#{@config.dir.build}/#{@appliance_config.appliance_path}/tmp/ec2-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

      fstab_64bit = "#{@config.dir.base}/src/ec2/fstab_64bit"
      fstab_32bit = "#{@config.dir.base}/src/ec2/fstab_32bit"
      ifcfg_eth0 = "#{@config.dir.base}/src/ec2/ifcfg-eth0"
      rc_local_file = "#{@config.dir.base}/src/ec2/rc_local"

      rpm_kernel = AWS_DEFAULTS[:kernel_rpm][@appliance_config.hardware.arch]

      rpm_other = {
              "ec2-ami-tools.noarch.rpm" => "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm"
      }

      cache_rpms( rpm_other )

      # TODO add progress bar?
      @log.debug "Preparing disk for EC2 image..."
      @exec_helper.execute "dd if=/dev/zero of=#{@appliance_config.path.file.ec2} bs=1 count=0 seek=#{10 * 1024}M"
      @log.debug "Disk for EC2 image prepared"

      @log.debug "Creating filesystem..."
      @exec_helper.execute "mke2fs -Fj #{@appliance_config.path.file.ec2}"
      @log.debug "Filesystem created"

      `mkdir -p #{ec2_mount_dir}`

      @exec_helper.execute "sudo mount -o loop #{@appliance_config.path.file.ec2} #{ec2_mount_dir}"

      disk_size = 0

      for part in @appliance_config.hardware.partitions.values
        disk_size += part['size']
      end

      # TODO is this really true? Need source
      if disk_size > 2
        offset = 32256
      else
        offset = 512
      end

      loop_device = get_loop_device
      mount_image( loop_device, @appliance_config.path.file.raw, offset )

      @log.debug "Syncing files between RAW and EC2 file..."
      @exec_helper.execute "sudo rsync -u -r -a  #{@raw_file_mount_directory}/* #{ec2_mount_dir}"
      @log.debug "Syncing finished"

      umount_image( loop_device, @appliance_config.path.file.raw )

      @exec_helper.execute "sudo umount -d #{ec2_mount_dir}"

      `rm -rf #{ec2_mount_dir}`

      guestfs_helper = GuestFSHelper.new( @appliance_config.path.file.ec2 )
      guestfs = guestfs_helper.guestfs

      @log.debug "Creating required devices..."
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x console" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x null" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x zero" )
      @log.debug "Devices created."

      @log.debug "Uploading '/etc/fstab' file..."
      fstab_file = @appliance_config.is64bit? ? fstab_64bit : fstab_32bit
      guestfs.upload( fstab_file, "/etc/fstab" )
      @log.debug "'/etc/fstab' file uploaded."

      guestfs.mkdir( "/data" ) if @appliance_config.is64bit?

      # enable networking on default runlevels
      @log.debug "Enabling networking..."
      guestfs.sh( "/sbin/chkconfig network on" )
      guestfs.upload( ifcfg_eth0, "/etc/sysconfig/network-scripts/ifcfg-eth0" )
      @log.debug "Networking enabled."

      @log.debug "Uploading '/etc/rc.local' file..."
      rc_local = Tempfile.new('rc_local')
      rc_local << guestfs.read_file( "/etc/rc.local" ) + File.new( rc_local_file ).read
      rc_local.flush

      guestfs.upload( rc_local.path, "/etc/rc.local" )

      rc_local.close
      @log.debug "'/etc/rc.local' file uploaded."

      guestfs_helper.rebuild_rpm_database

      @log.debug "Installing Xen kernel (#{rpm_kernel})..."
      guestfs.sh( "rpm -Uvh #{rpm_kernel}" )
      @log.debug "Xen kernel installed."

      @log.debug "Installing additional packages (#{rpm_other.keys.join( ", " )})..."
      guestfs.mkdir_p("/tmp/rpms")

      for name in rpm_other.keys
        cache_file = "#{@config.dir_src_cache}/#{name}"
        guestfs.upload( cache_file, "/tmp/rpms/#{name}" )
      end

      guestfs.sh( "yum -y --nogpgcheck localinstall /tmp/rpms/*.rpm" )
      guestfs.rm_rf("/tmp/rpms")
      @log.debug "Additional packages installed."

      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # disable password authentication
      guestfs.aug_set( "/files/etc/ssh/sshd_config/PasswordAuthentication", "no" )
      guestfs.aug_save
      @log.debug "Augeas changes saved."

      if @appliance_config.os.name.eql?("fedora") and @appliance_config.os.version.to_s.eql?("12")
        @log.debug "Downgrading udev package to use in EC2 environment..."
        guestfs.sh( "yum -y downgrade udev-142" )
        guestfs.upload( "#{@config.dir.base}/src/f12/yum.conf", "/etc/yum.conf" )
        @log.debug "Package udev downgraded."
      end

      guestfs.close

      @log.debug "EC2 image prepared!"
    end

    def validate_options( options )
      options = {
              :packages => {},
              :repos => []
      }.merge(options)

      options[:packages][:yum] = options[:packages][:yum] || []
      options[:packages][:yum_local] = options[:packages][:yum_local] || []
      options[:packages][:rpm] = options[:packages][:rpm] || []

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

      guestfs_helper = GuestFSHelper.new( raw_file )
      guestfs = guestfs_helper.guestfs

      guestfs_helper.rebuild_rpm_database

      for repo in options[:repos]
        @log.debug "Installing repo file '#{repo}'..."
        guestfs.sh( "rpm -Uvh #{repo}" )
        @log.debug "Repo file '#{repo}' installed."
      end unless options[:repos].nil?

      for yum_package in options[:packages][:yum]
        @log.debug "Installing package '#{yum_package}'..."
        guestfs.sh( "yum -y install #{yum_package}" )
        @log.debug "Package '#{yum_package}' installed."
      end unless options[:packages][:yum].nil?

      for package in options[:packages][:rpm]
        @log.debug "Installing package '#{package}'..."
        guestfs.sh( "rpm -Uvh --force #{package}" )
        @log.debug "Package '#{package}' installed."
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
      FileUtils.mkdir_p( @raw_file_mount_directory )

      @exec_helper.execute( "sudo losetup -o #{offset.to_s} #{loop_device} #{raw_file}" )
      @exec_helper.execute( "sudo mount #{loop_device} -t ext3 #{@raw_file_mount_directory}")
    end

    def umount_image( loop_device, raw_file )
      @log.debug "Unmounting image #{File.basename( raw_file )}"

      @exec_helper.execute( "sudo umount -d #{@raw_file_mount_directory}" )
      #@exec_helper.execute( "sudo losetup -d #{loop_device}" )

      FileUtils.rm_rf( @raw_file_mount_directory )
    end
  end
end
