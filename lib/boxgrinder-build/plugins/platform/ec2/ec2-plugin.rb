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
require 'boxgrinder-build/helpers/linux-helper'
require 'tempfile'

module BoxGrinder
  class EC2Plugin < BasePlugin
    def after_init
      register_deliverable(:disk => "#{@appliance_config.name}.ec2")

      register_supported_os('fedora', ['13', '14', '15'])
      register_supported_os('centos', ['5'])
      register_supported_os('rhel', ['5', '6'])
    end

    def execute
      @linux_helper = LinuxHelper.new(:log => @log)

      @log.info "Converting #{@appliance_config.name} appliance image to EC2 format..."

      @image_helper.create_disk(@deliverables.disk, 10) # 10 GB destination disk

      @image_helper.customize([@previous_deliverables.disk, @deliverables.disk], :automount => false) do |guestfs, guestfs_helper|
        @image_helper.sync_filesystem(guestfs, guestfs_helper)

        guestfs_helper.load_selinux_policy

        if (@appliance_config.os.name == 'rhel' or @appliance_config.os.name == 'centos') and @appliance_config.os.version == '5'
          # Not sure why it's messed but this prevents booting on AWS
          recreate_journal(guestfs)

          # Remove normal kernel
          guestfs.sh("yum -y remove kernel")
          # because we need to install kernel-xen package
          guestfs.sh("yum -y install kernel-xen")
          # and add require modules
          @linux_helper.recreate_kernel_image(guestfs, ['xenblk', 'xennet'])
        end

        # TODO is this really needed?
        @log.debug "Uploading '/etc/resolv.conf'..."
        guestfs.upload("/etc/resolv.conf", "/etc/resolv.conf")
        @log.debug "'/etc/resolv.conf' uploaded."

        create_devices(guestfs)

        guestfs.mkdir("/data") if @appliance_config.is64bit?

        upload_fstab(guestfs)
        enable_networking(guestfs)
        upload_rc_local(guestfs)
        add_ec2_user(guestfs)
        change_configuration(guestfs_helper)
        install_menu_lst(guestfs)

        enable_nosegneg_flag(guestfs) if @appliance_config.os.name == 'fedora'

        execute_post(guestfs_helper)
      end

      @log.info "Image converted to EC2 format."
    end

    def execute_post(guestfs_helper)
      unless @appliance_config.post['ec2'].nil?
        @appliance_config.post['ec2'].each do |cmd|
          guestfs_helper.sh(cmd, :arch => @appliance_config.hardware.arch)
        end
        @log.debug "Post commands from appliance definition file executed."
      else
        @log.debug "No commands specified, skipping."
      end
    end

    def recreate_journal(guestfs)
      @log.debug "Recreating EXT3 journal on root partition."
      guestfs.sh("tune2fs -j #{guestfs.list_devices.first}")
      @log.debug "Journal recreated."
    end

    def create_devices(guestfs)
      return if guestfs.exists('/sbin/MAKEDEV') == 0

      @log.debug "Creating required devices..."
      guestfs.sh("/sbin/MAKEDEV -d /dev -x console")
      guestfs.sh("/sbin/MAKEDEV -d /dev -x null")
      guestfs.sh("/sbin/MAKEDEV -d /dev -x zero")
      @log.debug "Devices created."
    end

    def disk_device_prefix
      disk = 'xv'
      disk = 's' if (@appliance_config.os.name == 'rhel' or @appliance_config.os.name == 'centos') and @appliance_config.os.version == '5'

      disk
    end

    def upload_fstab(guestfs)
      @log.debug "Uploading '/etc/fstab' file..."

      fstab_file = @appliance_config.is64bit? ? "#{File.dirname(__FILE__)}/src/fstab_64bit" : "#{File.dirname(__FILE__)}/src/fstab_32bit"

      fstab_data = File.open(fstab_file).read
      fstab_data.gsub!(/#DISK_DEVICE_PREFIX#/, disk_device_prefix)
      fstab_data.gsub!(/#FILESYSTEM_TYPE#/, @appliance_config.hardware.partitions['/']['type'])

      fstab = Tempfile.new('fstab')
      fstab << fstab_data
      fstab.flush

      guestfs.upload(fstab.path, "/etc/fstab")

      fstab.close

      @log.debug "'/etc/fstab' file uploaded."
    end

    def install_menu_lst(guestfs)
      @log.debug "Uploading '/boot/grub/menu.lst' file..."
      menu_lst_data = File.open("#{File.dirname(__FILE__)}/src/menu.lst").read

      menu_lst_data.gsub!(/#TITLE#/, @appliance_config.name)
      menu_lst_data.gsub!(/#KERNEL_VERSION#/, @linux_helper.kernel_version(guestfs))
      menu_lst_data.gsub!(/#KERNEL_IMAGE_NAME#/, @linux_helper.kernel_image_name(guestfs))

      menu_lst = Tempfile.new('menu_lst')
      menu_lst << menu_lst_data
      menu_lst.flush

      guestfs.upload(menu_lst.path, "/boot/grub/menu.lst")

      menu_lst.close
      @log.debug "'/boot/grub/menu.lst' file uploaded."
    end

    # This fixes issues with Fedora 14 on EC2: https://bugzilla.redhat.com/show_bug.cgi?id=651861#c39
    def enable_nosegneg_flag(guestfs)
      @log.debug "Enabling nosegneg flag..."
      guestfs.sh("echo \"hwcap 1 nosegneg\" > /etc/ld.so.conf.d/libc6-xen.conf")
      guestfs.sh("/sbin/ldconfig")
      @log.debug "Nosegneg enabled."
    end

    # https://issues.jboss.org/browse/BGBUILD-110
    def add_ec2_user(guestfs)
      @log.debug "Adding ec2-user user..."
      guestfs.sh("useradd ec2-user")
      guestfs.sh("echo -e 'ec2-user\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers")
      @log.debug "User ec2-user added."
    end

    # enable networking on default runlevels
    def enable_networking(guestfs)
      @log.debug "Enabling networking..."
      guestfs.sh("/sbin/chkconfig network on")
      guestfs.upload("#{File.dirname(__FILE__)}/src/ifcfg-eth0", "/etc/sysconfig/network-scripts/ifcfg-eth0")
      @log.debug "Networking enabled."
    end

    def upload_rc_local(guestfs)
      @log.debug "Uploading '/etc/rc.local' file..."
      rc_local = Tempfile.new('rc_local')
      rc_local << guestfs.read_file("/etc/rc.local") + File.read("#{File.dirname(__FILE__)}/src/rc_local")
      rc_local.flush

      guestfs.upload(rc_local.path, "/etc/rc.local")

      rc_local.close
      @log.debug "'/etc/rc.local' file uploaded."
    end

    def change_configuration(guestfs_helper)
      guestfs_helper.augeas do
        # disable password authentication
        set("/etc/ssh/sshd_config", "PasswordAuthentication", "no")

        # disable root login
        set("/etc/ssh/sshd_config", "PermitRootLogin", "no")
      end
    end
  end
end

plugin :class => BoxGrinder::EC2Plugin, :type => :platform, :name => :ec2, :full_name => "Amazon Elastic Compute Cloud (Amazon EC2)"
