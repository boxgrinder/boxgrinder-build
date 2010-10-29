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
      @log    = Logger.new('/dev/null')
      @helper = GuestFSHelper.new('a/raw/disk', :log => @log)
    end

    def prepare_and_launch( partitions )
      guetfs = mock('Guestfs')
      guetfs.should_receive(:set_append).with('noapic')
      guetfs.should_receive(:set_verbose)
      guetfs.should_receive(:set_trace)

      File.should_receive(:exists?).with('/usr/share/qemu-stable/bin/qemu.wrapper').and_return(true)

      guetfs.should_receive(:set_qemu).with('/usr/share/qemu-stable/bin/qemu.wrapper')
      guetfs.should_receive(:add_drive).with('a/raw/disk')
      guetfs.should_receive(:set_network).with(1)
      guetfs.should_receive(:launch)
      guetfs.should_receive(:list_partitions).and_return( partitions )

      Guestfs.should_receive(:create).and_return(guetfs)

      guetfs
    end

    it "should prepare and run guestfs" do
      prepare_and_launch(['/', '/boot'])

      @helper.should_receive(:mount_partitions).with(no_args)

      @helper.execute.should == @helper
    end

    it "should prepare and run guestfs with one partition" do
      guestfs = prepare_and_launch(['/'])

      guestfs.should_receive(:list_partitions).and_return(['/'])
      @helper.should_receive(:mount_partition).with("/", "/")

      @helper.execute.should == @helper
    end

    it "should prepare and run guestfs with no partitions" do
      guestfs = prepare_and_launch([])

      guestfs.should_receive(:list_devices).and_return(['/dev/sda'])
      @helper.should_receive(:mount_partition).with("/dev/sda", "/")

      @helper.execute.should == @helper
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

    it "should rebuild RPM database for Fedora" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:sh).with("rm -f /var/lib/rpm/__db.*")
      guestfs.should_receive(:sh).with("rpm --rebuilddb")

      @helper.instance_variable_set(:@guestfs, guestfs)
      @helper.rebuild_rpm_database
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



  end
end
