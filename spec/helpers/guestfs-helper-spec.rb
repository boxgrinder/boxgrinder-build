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

require 'boxgrinder-build/helpers/guestfs-helper'

module BoxGrinder
  describe GuestFSHelper do
    before(:each) do
      @log = Logger.new('/dev/null')
      @helper = GuestFSHelper.new('a/raw/disk', :log => @log)
    end

    describe ".execute" do
      it "should prepare and run guestfs" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)
        @helper.should_receive(:load_selinux_policy)

        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)
        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_partitions).and_return(['/', '/boot'])

        Guestfs.should_receive(:create).and_return(guestfs)

        @helper.should_receive(:mount_partitions).with(no_args)
        @helper.execute.should == @helper
      end

      it "should prepare and run guestfs wid IDE disk" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)
        @helper.should_receive(:load_selinux_policy)

        guestfs.should_receive(:add_drive_with_if).with('a/raw/disk', 'ide')
        guestfs.should_receive(:set_network).with(1)
        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_partitions).and_return(['/', '/boot'])

        Guestfs.should_receive(:create).and_return(guestfs)

        @helper.should_receive(:mount_partitions).with(no_args)
        @helper.execute(nil, :ide_disk => true).should == @helper
      end

      it "should prepare and run guestfs without HW accelerarion enabled for 64 bit host" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)

        @helper.should_receive(:hw_virtualization_available?).and_return(false)
        @helper.should_receive(:load_selinux_policy)

        RbConfig::CONFIG.should_receive(:[]).with('host_cpu').and_return('x86_64')

        File.should_receive(:exists?).with('/usr/bin/qemu-system-x86_64').and_return(true)
        guestfs.should_receive(:set_qemu).with('/usr/bin/qemu-system-x86_64')
        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)
        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_partitions).and_return(['/', '/boot'])

        Guestfs.should_receive(:create).and_return(guestfs)

        @helper.should_receive(:mount_partitions).with(no_args)
        @helper.execute.should == @helper
      end

      it "should prepare and run guestfs without HW accelerarion enabled for 32 bit host" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)

        @helper.should_receive(:hw_virtualization_available?).and_return(false)
        @helper.should_receive(:load_selinux_policy)

        RbConfig::CONFIG.should_receive(:[]).with('host_cpu').and_return('i386')

        File.should_receive(:exists?).with('/usr/bin/qemu').and_return(true)
        guestfs.should_receive(:set_qemu).with('/usr/bin/qemu')
        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)
        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_partitions).and_return(['/', '/boot'])

        Guestfs.should_receive(:create).and_return(guestfs)

        @helper.should_receive(:mount_partitions).with(no_args)
        @helper.execute.should == @helper
      end

      it "should prepare and run guestfs with one partition" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)
        @helper.should_receive(:load_selinux_policy)

        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)
        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_partitions).and_return(['/'])

        Guestfs.should_receive(:create).and_return(guestfs)

        guestfs.should_receive(:list_partitions).and_return(['/'])
        @helper.should_receive(:mount_partition).with("/", "/")

        @helper.execute.should == @helper
      end

      it "should prepare and run guestfs with no partitions" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)
        @helper.should_receive(:load_selinux_policy)

        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)
        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_partitions).and_return([])

        Guestfs.should_receive(:create).and_return(guestfs)

        guestfs.should_receive(:list_devices).and_return(['/dev/sda'])
        @helper.should_receive(:mount_partition).with("/dev/sda", "/")

        @helper.execute.should == @helper
      end
    end

    it "should close guestfs in clean way" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:sync)
      guestfs.should_receive(:umount_all)
      guestfs.should_receive(:close)

      @helper.instance_variable_set(:@guestfs, guestfs)

      @helper.clean_close
    end

    it "should mount partition" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:mount_options).with("", "/dev/sda", "/")

      @helper.instance_variable_set(:@guestfs, guestfs)
      @helper.mount_partition("/dev/sda", "/")
    end

    it "should mount partitions" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:list_partitions).and_return(['/boot', '/'])

      @helper.should_receive(:mount_partition).with('/boot', '/')
      guestfs.should_receive(:exists).with('/sbin/e2label').and_return(0)
      guestfs.should_receive(:umount).with('/boot')
      @helper.should_receive(:mount_partition).with('/', '/')
      guestfs.should_receive(:exists).with('/sbin/e2label').and_return(1)

      guestfs.should_receive(:list_partitions).and_return(['/boot', '/'])
      guestfs.should_receive(:sh).with('/sbin/e2label /boot').and_return('/boot')
      @helper.should_receive(:mount_partition).with('/boot', '/boot')

      @helper.instance_variable_set(:@guestfs, guestfs)
      @helper.mount_partitions
    end

    it "should mount partitions with new type of labels" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:list_partitions).and_return(['/boot', '/'])

      @helper.should_receive(:mount_partition).with('/boot', '/')
      guestfs.should_receive(:exists).with('/sbin/e2label').and_return(0)
      guestfs.should_receive(:umount).with('/boot')
      @helper.should_receive(:mount_partition).with('/', '/')
      guestfs.should_receive(:exists).with('/sbin/e2label').and_return(1)

      guestfs.should_receive(:list_partitions).and_return(['/boot', '/'])
      guestfs.should_receive(:sh).with('/sbin/e2label /boot').and_return('_/boot')
      @helper.should_receive(:mount_partition).with('/boot', '/boot')

      @helper.instance_variable_set(:@guestfs, guestfs)
      @helper.mount_partitions
    end

    it "should raise when no root partition is found" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:list_partitions).and_return(['/boot', '/'])

      @helper.should_receive(:mount_partition).with('/boot', '/')
      guestfs.should_receive(:exists).with('/sbin/e2label').and_return(0)
      guestfs.should_receive(:umount).with('/boot')
      @helper.should_receive(:mount_partition).with('/', '/')
      guestfs.should_receive(:exists).with('/sbin/e2label').and_return(0)
      guestfs.should_receive(:umount).with('/')

      @helper.instance_variable_set(:@guestfs, guestfs)

      begin
        @helper.mount_partitions
      rescue => e
        e.message.should == "No root partition found for 'disk' disk!"
      end
    end

    it "execute a command for current arch" do
      guestfs = mock('Guestfs')

      @helper.should_receive(:`).with('uname -m').and_return('bleh')
      @helper.instance_variable_set(:@guestfs, guestfs)

      guestfs.should_receive(:sh).with("setarch bleh << 'SETARCH_EOF'\ncommand\nSETARCH_EOF")

      @helper.sh("command")
    end

    it "execute a command for specified arch" do
      guestfs = mock('Guestfs')
      @helper.instance_variable_set(:@guestfs, guestfs)

      guestfs.should_receive(:sh).with("setarch arch << 'SETARCH_EOF'\ncommand\nSETARCH_EOF")

      @helper.sh("command", :arch => 'arch')
    end

    describe ".hw_virtualization_available?" do
      it "should return true if HW acceleration is available" do
        Resolv.should_receive(:getname).with("169.254.169.254").and_return("blah")
        @helper.should_receive(:`).with('cat /proc/cpuinfo | grep flags | grep vmx | wc -l').and_return("2")
        @helper.hw_virtualization_available?.should == true
      end

      it "should return false if no vmx flag is present" do
        Resolv.should_receive(:getname).with("169.254.169.254").and_return("blah")
        @helper.should_receive(:`).with('cat /proc/cpuinfo | grep flags | grep vmx | wc -l').and_return("0")
        @helper.hw_virtualization_available?.should == false
      end

      it "should return false if we're on EC2" do
        Resolv.should_receive(:getname).with("169.254.169.254").and_return("instance-data.ec2.internal")
        @helper.hw_virtualization_available?.should == false
      end
    end

    describe ".load_selinux_policy" do
      it "should load SElinux policy for SElinux enabled guests" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(1)
        guestfs.should_receive(:aug_init).with("/", 32)
        guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/sysconfig/selinux']")
        guestfs.should_receive(:aug_load)
        guestfs.should_receive(:aug_get).with("/files/etc/sysconfig/selinux/SELINUX").and_return('permissive')
        guestfs.should_receive(:sh).with("/usr/sbin/load_policy")
        guestfs.should_receive(:aug_close)

        @helper.load_selinux_policy
      end

      it "should not load SElinux policy for SElinux disabled guests" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(1)
        guestfs.should_receive(:aug_init).with("/", 32)
        guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/sysconfig/selinux']")
        guestfs.should_receive(:aug_load)
        guestfs.should_receive(:aug_get).with("/files/etc/sysconfig/selinux/SELINUX").and_return('disabled')
        guestfs.should_not_receive(:sh).with("/usr/sbin/load_policy")
        guestfs.should_receive(:aug_close)

        @helper.load_selinux_policy
      end
    end
  end
end
