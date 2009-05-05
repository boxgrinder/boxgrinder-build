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
require 'jboss-cloud/exec'

module JBossCloud
  class ApplianceImageCustomize < Rake::TaskLib

    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config

      @appliance_build_dir          = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @bundle_dir                   = "#{@appliance_build_dir}/ec2/bundle"
      @appliance_xml_file           = "#{@appliance_build_dir}/#{@appliance_config.name}.xml"
      @appliance_ec2_image_file     = "#{@appliance_build_dir}/#{@appliance_config.name}.ec2"
      @mount_directory              = "#{@config.dir.build}/appliances/#{@config.build_path}/tmp/customize-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"
    end

    def convert_to_ami
      loop_device = get_loop_device

      mount_image( loop_device, @appliance_ec2_image_file )

      `sudo mkdir -p #{@mount_directory}/dev`
      `sudo mkdir -p #{@mount_directory}/data`

      `sudo /sbin/MAKEDEV -d #{@mount_directory}/dev -x console`
      `sudo /sbin/MAKEDEV -d #{@mount_directory}/dev -x null`
      `sudo /sbin/MAKEDEV -d #{@mount_directory}/dev -x zero`

      fstab_file = "#{@mount_directory}/etc/fstab"
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

      echo( "#{@mount_directory}/etc/fstab", fstab_data )

      # enable networking on default runlevels
      `sudo chroot #{@mount_directory} /sbin/chkconfig --level 345 network on`

      # enable DHCP
      echo( "#{@mount_directory}/etc/sysconfig/network-scripts/ifcfg-eth0", "DEVICE=eth0\nBOOTPROTO=dhcp\nONBOOT=yes\nTYPE=Ethernet\nUSERCTL=yes\nPEERDNS=yes\nIPV6INIT=no\n" )

      umount_image( loop_device, @appliance_ec2_image_file )
    end

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

    # TODO rewrite this!!!

    def customize( raw_file, packages = {}, repos = [] )
      if ( packages[:yum_local].nil? and packages[:yum].nil? and packages[:rpm_remote].nil? and repos.size == 0)
        puts "No additional local or remote packages to install, skipping..."
        # silent return, we don't have any packages to install
        return
      end

      raise ValidationError, "Raw file '#{raw_file}' doesn't exists, please specify valid raw file" if !File.exists?( raw_file )

      loop_device = get_loop_device
      mount_image( loop_device, raw_file )

      for repo in repos
        execute_command( "sudo chroot #{@mount_directory} rpm -Uvh #{repo}" )
      end

      install_packages( packages )
      umount_image( loop_device, raw_file )
    end

    protected

    def mount_image( loop_device, raw_file, offset = 32256, appliance_jbcs_dir = "tmp/jboss-cloud-support", appliance_rpms_dir = "tmp/jboss-cloud-support-rpms" )
      puts "Mounting image #{File.basename( raw_file )}"

      FileUtils.mkdir_p( @mount_directory )

      `sudo losetup -o #{offset.to_s} #{loop_device} #{raw_file}`

      `sudo mount #{loop_device} -t ext3 #{@mount_directory}`
      `mkdir -p #{@mount_directory}/#{appliance_jbcs_dir}`
      `mkdir -p #{@mount_directory}/#{appliance_rpms_dir}`
      #`sudo mount -t sysfs none #{@mount_directory}/sys/`
      #`sudo mount -o bind /dev/ #{@mount_directory}/dev/`
      `sudo mount -t proc none #{@mount_directory}/proc/`
      `sudo mount -o bind /etc/resolv.conf #{@mount_directory}/etc/resolv.conf`
      `sudo mount -o bind #{@config.dir.base} #{@mount_directory}/#{appliance_jbcs_dir}`
      `sudo mount -o bind #{@config.dir.top}/#{@appliance_config.os_path}/RPMS #{@mount_directory}/#{appliance_rpms_dir}`
    end

    def umount_image( loop_device, raw_file, appliance_jbcs_dir = "tmp/jboss-cloud-support", appliance_rpms_dir = "tmp/jboss-cloud-support-rpms"  )
      puts "Unmounting image #{File.basename( raw_file )}"

      #`sudo umount #{@mount_directory}/sys`
      #`sudo umount #{@mount_directory}/dev`
      `sudo umount #{@mount_directory}/proc`
      `sudo umount #{@mount_directory}/etc/resolv.conf`
      `sudo umount #{@mount_directory}/#{appliance_jbcs_dir}`
      `sudo umount #{@mount_directory}/#{appliance_rpms_dir}`

      `rm -rf #{@mount_directory}/#{appliance_jbcs_dir}`
      `rm -rf #{@mount_directory}/#{appliance_rpms_dir}`

      `sudo umount #{@mount_directory}`
      `sudo losetup -d #{loop_device}`

      FileUtils.rm_rf( @mount_directory )
    end

    def install_packages( packages, appliance_jbcs_dir = "tmp/jboss-cloud-support", appliance_rpms_dir = "tmp/jboss-cloud-support-rpms" )
      return if packages.size == 0

      # import our GPG key
      execute_command( "sudo chroot #{@mount_directory} rpm --import /#{appliance_jbcs_dir}/src/jboss-cloud-release/RPM-GPG-KEY-oddthesis" )

      for local_package in packages[:yum_local]
        puts "Installing package #{File.basename( local_package )}..."
        execute_command( "sudo chroot #{@mount_directory} yum -y localinstall /#{appliance_rpms_dir}/#{local_package}" )
      end unless packages[:yum_local].nil?

      for yum_package in packages[:yum]
        puts "Installing package #{yum_package}..."
        execute_command( "sudo chroot #{@mount_directory} yum -y install #{yum_package}" )
      end unless packages[:yum].nil?

      for package in packages[:rpm_remote]
        puts "Installing package #{package}..."
        execute_command( "sudo chroot #{@mount_directory} rpm -Uvh --force #{package}" )
      end unless packages[:rpm_remote].nil?
    end
  end
end
