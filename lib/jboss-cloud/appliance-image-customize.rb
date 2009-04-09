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

module JBossCloud
  class ApplianceImageCustomize < Rake::TaskLib
    
    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config
    end
    
    def customize( raw_file, packages = {} )
      
      if ( packages[:local].nil? and packages[:remote].nil? )
        puts "No additional local or remote packages to install, skipping..."
        # silent return, we don't have any packages to install
        return
      end
      
      raise ValidationError, "Raw file '#{raw_file}' doesn't exists, please specify valid raw file" if !File.exists?( raw_file )
      
      mount_directory = "#{@config.dir.build}/appliances/#{@config.build_path}/tmp/vmware-mount-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"
      
      loop_device = `sudo losetup -f 2>&1`.strip
      
      if !loop_device.match( /^\/dev\/loop/ )
        raise "No free loop devices available, please free at least one. See 'losetup -d' command."
      end
      
      appliance_jbcs_dir = "tmp/jboss-cloud-support"
      appliance_rpms_dir = "tmp/jboss-cloud-support-rpms"
      
      FileUtils.mkdir_p( mount_directory )
      
      mount_image( loop_device, raw_file, mount_directory, appliance_jbcs_dir, appliance_rpms_dir )
      install( packages, mount_directory, appliance_jbcs_dir, appliance_rpms_dir )
      umount_image( loop_device, raw_file, mount_directory, appliance_jbcs_dir, appliance_rpms_dir )
      
      FileUtils.rm_rf( mount_directory )
    end
    
    protected
    
    def mount_image( loop_device, raw_file, mount_directory, appliance_jbcs_dir, appliance_rpms_dir )
      puts "Mounting image #{File.basename( raw_file )}"
      
      `sudo losetup -o 32256 #{loop_device} #{raw_file}`     
      
      `sudo mount #{loop_device} -t ext3 #{mount_directory}`
      `mkdir -p #{mount_directory}/#{appliance_jbcs_dir}`
      `mkdir -p #{mount_directory}/#{appliance_rpms_dir}`
      `sudo mount -t sysfs none #{mount_directory}/sys/`
      `sudo mount -o bind /dev/ #{mount_directory}/dev/`
      `sudo mount -t proc none #{mount_directory}/proc/`
      `sudo mount -o bind /etc/resolv.conf #{mount_directory}/etc/resolv.conf`
      `sudo mount -o bind #{@config.dir.base} #{mount_directory}/#{appliance_jbcs_dir}`
      `sudo mount -o bind #{@config.dir.top}/#{@appliance_config.os_path}/RPMS #{mount_directory}/#{appliance_rpms_dir}`
    end
    
    def umount_image( loop_device, raw_file, mount_directory, appliance_jbcs_dir, appliance_rpms_dir  )
      puts "Unmounting image #{File.basename( raw_file )}"
      
      `sudo umount #{mount_directory}/sys`
      `sudo umount #{mount_directory}/dev`
      `sudo umount #{mount_directory}/proc`
      `sudo umount #{mount_directory}/etc/resolv.conf`      
      `sudo umount #{mount_directory}/#{appliance_jbcs_dir}`
      `sudo umount #{mount_directory}/#{appliance_rpms_dir}`
      
      `rm -rf #{mount_directory}/#{appliance_jbcs_dir}`
      `rm -rf #{mount_directory}/#{appliance_rpms_dir}`
      
      `sudo umount #{mount_directory}`
      `sudo losetup -d #{loop_device}`
    end
    
    def install( packages, mount_directory, appliance_jbcs_dir, appliance_rpms_dir )
      # import our GPG key
      execute_command( "sudo chroot #{mount_directory} rpm --import /#{appliance_jbcs_dir}/src/jboss-cloud-release/RPM-GPG-KEY-oddthesis" )
      
      for local_package in packages[:local]
        puts "Installing package #{File.basename( local_package )}..."
        execute_command( "sudo chroot #{mount_directory} yum -y localinstall /#{appliance_rpms_dir}/#{local_package}" )
      end
    end
  end
end
