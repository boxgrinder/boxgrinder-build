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
require 'fileutils'
require 'boxgrinder/validator/errors'
require 'yaml'
require 'AWS'
require 'aws/s3'
require 'boxgrinder/aws/aws-support'
require 'boxgrinder/appliance-image-customize'
include AWS::S3

module BoxGrinder
  class EC2Image < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config            = config
      @appliance_config  = appliance_config

      @log          = options[:log]         || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new( { :log => @log } )

      @appliance_image_customizer = ApplianceImageCustomize.new( @config, @appliance_config )

      define_tasks
    end

    def define_tasks
      directory @appliance_config.path.dir.ec2.build
      directory @appliance_config.path.dir.ec2.bundle

      # TODO we should depend on actual disk file, not xml I think
      file @appliance_config.path.file.ec2.disk  => [ @appliance_config.path.file.raw.xml, @appliance_config.path.dir.ec2.build ] do
        convert_image_to_ec2_format
      end

      file @appliance_config.path.file.ec2.manifest => [ @appliance_config.path.file.ec2.disk, @appliance_config.path.dir.ec2.bundle ] do
        @aws_support = AWSSupport.new( @config )
        bundle_image
      end

      task "appliance:#{@appliance_config.name}:ec2:upload" => [ @appliance_config.path.file.ec2.manifest ] do
        @aws_support = AWSSupport.new( @config )
        upload_image
      end

      task "appliance:#{@appliance_config.name}:ec2:register" => [ "appliance:#{@appliance_config.name}:ec2:upload" ] do
        @aws_support = AWSSupport.new( @config )
        register_image
      end

      desc "Build #{@appliance_config.simple_name} appliance for Amazon EC2"
      task "appliance:#{@appliance_config.name}:ec2" => [ @appliance_config.path.file.ec2.disk ]
    end

    def bundle_image
      @log.info "Bundling AMI..."

      @exec_helper.execute( "ec2-bundle-image -i #{@appliance_config.path.file.ec2.disk} --kernel #{AWS_DEFAULTS[:kernel_id][@appliance_config.hardware.arch]} --ramdisk #{AWS_DEFAULTS[:ramdisk_id][@appliance_config.hardware.arch]} -c #{@aws_support.aws_data['cert_file']} -k #{@aws_support.aws_data['key_file']} -u #{@aws_support.aws_data['account_number']} -r #{@appliance_config.hardware.arch} -d #{@appliance_config.path.dir.ec2.bundle}" )

      @log.info "Bundling AMI finished."
    end

    def appliance_already_uploaded?
      begin
        bucket = Bucket.find( @config.release.s3['bucket_name'] )
      rescue
        return false
      end

      manifest_location = @aws_support.bucket_manifest_key( @appliance_config.name )
      manifest_location = manifest_location[ manifest_location.index( "/" ) + 1, manifest_location.length ]

      for object in bucket.objects do
        return true if object.key.eql?( manifest_location )
      end

      false
    end

    def upload_image
      if appliance_already_uploaded?
        @log.debug "Image for #{@appliance_config.simple_name} appliance is already uploaded, skipping..."
        return
      end

      @log.info "Uploading #{@appliance_config.simple_name} AMI to bucket '#{@config.release.s3['bucket_name']}'..."

      @exec_helper.execute( "ec2-upload-bundle -b #{@aws_support.bucket_key( @appliance_config.name )} -m #{@appliance_config.path.file.ec2.manifest} -a #{@aws_support.aws_data['access_key']} -s #{@aws_support.aws_data['secret_access_key']} --retry" )
    end

    def register_image
      ami_info    = @aws_support.ami_info( @appliance_config.name )

      if ami_info
        @log.info "Image is registered under id: #{ami_info.imageId}"
        return
      else
        ami_info = @aws_support.ec2.register_image( :image_location => @aws_support.bucket_manifest_key( @appliance_config.name ) )
        @log.info "Image successfully registered under id: #{ami_info.imageId}."
      end
    end

    def convert_image_to_ec2_format
      @log.info "Converting #{@appliance_config.simple_name} appliance image to EC2 format..."

      ec2_disk_mount_dir  = "#{@config.dir.build}/#{@appliance_config.appliance_path}/tmp/ec2-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"
      raw_disk_mount_dir  = "#{@config.dir.build}/#{@appliance_config.appliance_path}/tmp/raw-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

      fstab_64bit   = "#{@config.dir.base}/src/ec2/fstab_64bit"
      fstab_32bit   = "#{@config.dir.base}/src/ec2/fstab_32bit"
      ifcfg_eth0    = "#{@config.dir.base}/src/ec2/ifcfg-eth0"
      rc_local_file = "#{@config.dir.base}/src/ec2/rc_local"

      rpms = {
              File.basename(AWS_DEFAULTS[:kernel_rpm][@appliance_config.hardware.arch]) => AWS_DEFAULTS[:kernel_rpm][@appliance_config.hardware.arch],
              "ec2-ami-tools.noarch.rpm" => "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm"
      }

      cache_rpms( rpms )

      ec2_prepare_disk
      ec2_create_filesystem

      FileUtils.mkdir_p(  ec2_disk_mount_dir )
      @exec_helper.execute "sudo mount -o loop #{@appliance_config.path.file.ec2.disk} #{ec2_disk_mount_dir}"

      loop_device = get_loop_device
      offset = calculate_disk_offset( loop_device, @appliance_config.path.file.raw.disk )

      loop_device = get_loop_device

      mount_image(@appliance_config.path.file.raw.disk, raw_disk_mount_dir, loop_device, offset )

      sync_files( raw_disk_mount_dir, ec2_disk_mount_dir )

      umount_image( @appliance_config.path.file.raw.disk, raw_disk_mount_dir )
      umount_image( @appliance_config.path.file.ec2.disk, ec2_disk_mount_dir )

      guestfs_helper = GuestFSHelper.new( @appliance_config.path.file.ec2.disk )
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

      @log.debug "Installing additional packages (#{rpms.keys.join( ", " )})..."
      guestfs.mkdir_p("/tmp/rpms")

      for name in rpms.keys
        cache_file = "#{@config.dir_src_cache}/#{name}"
        guestfs.upload( cache_file, "/tmp/rpms/#{name}" )
      end

      guestfs.sh( "rpm -Uvh --nodeps /tmp/rpms/*.rpm" )
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

        #@log.debug "Disabling unnecessary services..."
        #guestfs.sh( "/sbin/chkconfig ksm off" ) if guestfs.exists( "/etc/init.d/ksm" )
        #guestfs.sh( "/sbin/chkconfig ksmtuned off" ) if guestfs.exists( "/etc/init.d/ksmtuned" )
        #@log.debug "Services disabled."
      end

      guestfs.close

      @log.debug "EC2 image prepared!"

      @log.info "Image converted to EC2 format."
    end

    def ec2_prepare_disk
      # TODO add progress bar?
      @log.debug "Preparing disk for EC2 image..."
      @exec_helper.execute "dd if=/dev/zero of=#{@appliance_config.path.file.ec2.disk} bs=1 count=0 seek=#{10 * 1024}M"
      @log.debug "Disk for EC2 image prepared"
    end

    def ec2_create_filesystem
      @log.debug "Creating filesystem..."
      @exec_helper.execute "mkfs.ext3 -F #{@appliance_config.path.file.ec2.disk}"
      @log.debug "Filesystem created"
    end

    def calculate_disk_offset( loop_device, disk )
      @exec_helper.execute( "sudo losetup #{loop_device} #{disk}" )
      offset = @exec_helper.execute("sudo parted -m #{loop_device} 'unit B print' | grep '^1' | awk -F: '{ print $2 }'").strip.chop
      @exec_helper.execute( "sudo losetup -d #{loop_device}" )

      offset
    end

    def mount_image( disk, mount_dir, loop_device, offset )
      @log.debug "Mounting image #{File.basename( disk )} in #{mount_dir} using #{loop_device} with offset #{offset}"
      FileUtils.mkdir_p(  mount_dir )
      @exec_helper.execute( "sudo losetup -o #{offset.to_s} #{loop_device} #{disk}" )
      @exec_helper.execute( "sudo mount #{loop_device} -t ext3 #{ mount_dir}")
    end

    def umount_image( disk, mount_dir )
      @log.debug "Unmounting image #{File.basename( disk )}"
      @exec_helper.execute( "sudo umount -d #{ mount_dir}" )
      FileUtils.rm_rf(  mount_dir )
    end


    def sync_files( from_dir, to_dir )
      @log.debug "Syncing files between #{from_dir} and #{to_dir}..."
      @exec_helper.execute "sudo rsync -u -r -a  #{ from_dir}/* #{to_dir}"
      @log.debug "Sync finished."
    end

    def cache_rpms( rpms )
      for name in rpms.keys
        cache_file = "#{@config.dir.src_cache}/#{name}"

        if ( ! File.exist?( cache_file ) )
          FileUtils.mkdir_p( @config.dir.src_cache )
          @exec_helper.execute( "wget #{rpms[name]} -O #{cache_file}" )
        end
      end
    end

    def get_loop_device
      begin
        loop_device = @exec_helper.execute("sudo losetup -f 2>&1").strip
      rescue
        raise "No free loop devices available, please free at least one. See 'losetup -d' command."
      end

      loop_device
    end
  end
end
