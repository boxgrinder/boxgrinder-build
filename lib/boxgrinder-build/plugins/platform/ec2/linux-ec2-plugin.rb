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

require 'boxgrinder-build/plugins/base-plugin'
require 'tempfile'

module BoxGrinder
  class LinuxEC2Plugin < BasePlugin
    #        :modules => { "i386" => "http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21.7-2.ec2.v1.2.fc8xen-i686.tgz", "x86_64" => "http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21.7-2.ec2.v1.2.fc8xen-x86_64.tgz" }

    SUPPORTED_OSES = {
            'fedora' => [ "11" ]
    }

    REGIONS = { 'us_east' => 'url' }

    KERNELS = {
            'us_east' => {
                    'fedora' => {
                            '11' => {
                                    'i386'     => { :aki => 'aki-a71cf9ce', :ari => 'ari-a51cf9cc', :rpm => 'http://repo.oddthesis.org/packages/other/kernel-xen-2.6.21.7-2.fc8.i686.rpm' },
                                    'x86_64'   => { :aki => 'aki-b51cf9dc', :ari => 'ari-b31cf9da', :rpm => 'http://repo.oddthesis.org/packages/other/kernel-xen-2.6.21.7-2.fc8.x86_64.rpm' }
                            }
                    }
            }
    }

    def after_init
      base_path = "#{@config.dir.build}/#{@appliance_config.appliance_path}"

      @directories = {
              :build => "#{base_path}/ec2",
              :ec2_disk_mount_dir => "#{base_path}/tmp/ec2-#{rand(9999999999).to_s.center(10, rand(9).to_s)}",
              :raw_disk_mount_dir => "#{base_path}/tmp/raw-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"
      }

      @files = {
              :ec2_disk => "#{@directories[:build]}/#{@appliance_config.name}.ec2"
      }
    end

    def supported_os
      supported = ""

      SUPPORTED_OSES.each_key do |os_name|
        supported << "#{os_name}, versions: #{SUPPORTED_OSES[os_name].join(", ")}"
      end

      supported
    end

    def convert( raw_disk )
      if File.exists?( @files[:ec2_disk] )
        @log.info "EC2 image for #{@appliance_config.name} appliance already exists, skipping..."
        return @files[:ec2_disk]
      end

      unless SUPPORTED_OSES[@appliance_config.os.name].include?( @appliance_config.os.version )
        @log.error "EC2 platform plugin for Linux operating systems supports: #{supported_os}. Your OS is #{@appliance_config.os.name} #{@appliance_config.os.version}."
        return
      end

      FileUtils.mkdir_p @directories[:build]

      @log.info "Converting #{@appliance_config.name} appliance image to EC2 format..."

      begin
        ec2_prepare_disk
        ec2_create_filesystem
      rescue => e
        raise "Error while preparing EC2 disk image. See logs for more info"
      end

      raw_disk_offset = calculate_disk_offset( raw_disk )

      begin
        ec2_loop_device = mount_image(@files[:ec2_disk], @directories[:ec2_disk_mount_dir] )
        raw_loop_device = mount_image(raw_disk, @directories[:raw_disk_mount_dir], raw_disk_offset )
      rescue => e
        raise "Error while mounting image. See logs for more info"
      end

      sync_files( @directories[:raw_disk_mount_dir], @directories[:ec2_disk_mount_dir]  )

      umount_image( raw_disk, @directories[:raw_disk_mount_dir], raw_loop_device )
      umount_image( @files[:ec2_disk], @directories[:ec2_disk_mount_dir], ec2_loop_device )

      customize( @files[:ec2_disk]) do |guestfs, guestfs_helper|
        create_devices( guestfs )
        upload_fstab( guestfs )

        guestfs.mkdir( "/data" ) if @appliance_config.is64bit?

        enable_networking( guestfs )
        upload_rc_local( guestfs )

        guestfs_helper.rebuild_rpm_database

        install_additional_packages( guestfs )
        change_configuration( guestfs )

#        if @appliance_config.os.name.eql?("fedora") and @appliance_config.os.version.to_s.eql?("12")
#          @log.debug "Downgrading udev package to use in EC2 environment..."
#
#          repo_included = false
#
#          @appliance_config.repos.each do |repo|
#            repo_included = true if repo['baseurl'] == "http://repo.boxgrinder.org/boxgrinder/packages/fedora/12/RPMS/#{@appliance_config.hardware.arch}"
#          end
#
#          guestfs.upload( "#{File.dirname( __FILE__ )}/src/f12-#{@appliance_config.hardware.arch}-boxgrinder.repo", "/etc/yum.repos.d/f12-#{@appliance_config.hardware.arch}-boxgrinder.repo" ) unless repo_included
#          guestfs.sh( "yum -y downgrade udev-142" )
#          guestfs.upload( "#{File.dirname( __FILE__ )}/src/f12/yum.conf", "/etc/yum.conf" )
#          guestfs.rm_rf( "/etc/yum.repos.d/f12-#{@appliance_config.hardware.arch}-boxgrinder.repo" ) unless repo_included
#
#          @log.debug "Package udev downgraded."
#
#          # TODO EC2 fix, remove that after Fedora pushes kernels to Amazon
#          @log.debug "Disabling unnecessary services..."
#          guestfs.sh( "/sbin/chkconfig ksm off" ) if guestfs.exists( "/etc/init.d/ksm" ) != 0
#          guestfs.sh( "/sbin/chkconfig ksmtuned off" ) if guestfs.exists( "/etc/init.d/ksmtuned" ) != 0
#          @log.debug "Services disabled."
#        end
      end

      @log.info "Image converted to EC2 format."
    end

    def ec2_prepare_disk
      # TODO add progress bar?
      # TODO using whole 10GB is fine?
      @log.debug "Preparing disk for EC2 image..."
      @exec_helper.execute "dd if=/dev/zero of=#{@files[:ec2_disk]} bs=1 count=0 seek=#{10 * 1024}M"
      @log.debug "Disk for EC2 image prepared"
    end

    def ec2_create_filesystem
      @log.debug "Creating filesystem..."
      @exec_helper.execute "mkfs.ext3 -F #{@files[:ec2_disk]}"
      @log.debug "Filesystem created"
    end

    def calculate_disk_offset( disk )
      loop_device = get_loop_device

      @exec_helper.execute( "sudo losetup #{loop_device} #{disk}" )
      offset = @exec_helper.execute("sudo parted #{loop_device} 'unit B print' | grep Number -A 1 | tail -n 1 | awk '{ print $2 }'").strip.chop.scan(/^\d+/).to_s
      @exec_helper.execute( "sudo losetup -d #{loop_device}" )

      offset
    end

    def mount_image( disk, mount_dir, offset = 0 )
      loop_device = get_loop_device

      @log.debug "Mounting image #{File.basename( disk )} in #{mount_dir} using #{loop_device} with offset #{offset}"
      FileUtils.mkdir_p( mount_dir )
      @exec_helper.execute( "sudo losetup -o #{offset.to_s} #{loop_device} #{disk}" )
      @exec_helper.execute( "sudo mount #{loop_device} -t ext3 #{ mount_dir}")

      loop_device
    end

    def umount_image( disk, mount_dir, loop_device )
      @log.debug "Unmounting image #{File.basename( disk )}"
      @exec_helper.execute( "sudo umount -d #{loop_device}" )
      FileUtils.rm_rf( mount_dir )
    end


    def sync_files( from_dir, to_dir )
      @log.debug "Syncing files between #{from_dir} and #{to_dir}..."
      @exec_helper.execute "sudo rsync -u -r -a  #{from_dir}/* #{to_dir}"
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

    def create_devices( guestfs )
      @log.debug "Creating required devices..."
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x console" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x null" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x zero" )
      @log.debug "Devices created."
    end

    def upload_fstab( guestfs )
      @log.debug "Uploading '/etc/fstab' file..."
      fstab_file = @appliance_config.is64bit? ? "#{File.dirname( __FILE__ )}/src/fstab_64bit" : "#{File.dirname( __FILE__ )}/src/fstab_32bit"
      guestfs.upload( fstab_file, "/etc/fstab" )
      @log.debug "'/etc/fstab' file uploaded."
    end

    # enable networking on default runlevels
    def enable_networking( guestfs )
      @log.debug "Enabling networking..."
      guestfs.sh( "/sbin/chkconfig network on" )
      guestfs.upload( "#{File.dirname( __FILE__ )}/src/ifcfg-eth0", "/etc/sysconfig/network-scripts/ifcfg-eth0" )
      @log.debug "Networking enabled."
    end

    def upload_rc_local( guestfs )
      @log.debug "Uploading '/etc/rc.local' file..."
      rc_local = Tempfile.new('rc_local')
      rc_local << guestfs.read_file( "/etc/rc.local" ) + File.read( "#{File.dirname( __FILE__ )}/src/rc_local" )
      rc_local.flush

      guestfs.upload( rc_local.path, "/etc/rc.local" )

      rc_local.close
      @log.debug "'/etc/rc.local' file uploaded."
    end

    def install_additional_packages( guestfs )
      rpms = {
              "ec2-ami-tools.noarch.rpm" => "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm"
      }

      kernel_rpm =  KERNELS['us_east'][@appliance_config.os.name][@appliance_config.os.version][@appliance_config.hardware.arch][:rpm]
      rpms[File.basename( kernel_rpm )] = kernel_rpm unless kernel_rpm.nil?

      cache_rpms( rpms )

      @log.debug "Installing additional packages (#{rpms.keys.join( ", " )})..."
      guestfs.mkdir_p("/tmp/rpms")

      for name in rpms.keys
        cache_file = "#{@config.dir.src_cache}/#{name}"
        guestfs.upload( cache_file, "/tmp/rpms/#{name}" )
      end

      guestfs.sh( "rpm -Uvh --nodeps /tmp/rpms/*.rpm" )
      guestfs.rm_rf("/tmp/rpms")
      @log.debug "Additional packages installed."
    end

    def change_configuration( guestfs )
      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # disable password authentication
      guestfs.aug_set( "/files/etc/ssh/sshd_config/PasswordAuthentication", "no" )
      guestfs.aug_save
      @log.debug "Augeas changes saved."
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
