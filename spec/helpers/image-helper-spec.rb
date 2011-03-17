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

require 'boxgrinder-build/helpers/image-helper'

module BoxGrinder
  describe ImageHelper do

    before(:each) do
      @config = mock('Config')

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '14'}))
      @appliance_config.stub!(:hardware).and_return(
          OpenCascade.new({
                              :partitions =>
                                  {
                                      '/' => {'size' => 2, 'type' => 'ext4'},
                                      '/home' => {'size' => 3, 'type' => 'ext3'},
                                  },
                              :arch => 'i686',
                              :base_arch => 'i386',
                              :cpus => 1,
                              :memory => 256,
                          })
      )

      @helper = ImageHelper.new(@config, @appliance_config, :log => Logger.new('/dev/null'))

      @log = @helper.instance_variable_get(:@log)
      @exec_helper = @helper.instance_variable_get(:@exec_helper)
    end

    describe ".customize" do
      it "should customize the disk image using GuestFS" do
        guestfs = mock('GuestFS')
        guestfs.should_receive(:abc)

        guestfs_helper = mock(GuestFSHelper)
        guestfs_helper.should_receive(:customize).with(:ide_disk => false).ordered.and_yield(guestfs, guestfs_helper)
        guestfs_helper.should_receive(:def)

        GuestFSHelper.should_receive(:new).with(['disk.raw'], @appliance_config, @config, :log => @log).and_return(guestfs_helper)

        @helper.customize(['disk.raw']) do |guestfs, guestfs_helper|
          guestfs.abc
          guestfs_helper.def
        end
      end

      it "should customize the disk image using GuestFS and selectind ide_disk option for RHEL/CentOS 5" do
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'rhel', :version => '5'}))

        guestfs = mock('GuestFS')
        guestfs.should_receive(:abc)

        guestfs_helper = mock(GuestFSHelper)
        guestfs_helper.should_receive(:customize).with(:ide_disk => true).ordered.and_yield(guestfs, guestfs_helper)
        guestfs_helper.should_receive(:def)

        GuestFSHelper.should_receive(:new).with(['disk.raw'], @appliance_config, @config,  :log => @log).and_return(guestfs_helper)

        @helper.customize(['disk.raw']) do |guestfs, guestfs_helper|
          guestfs.abc
          guestfs_helper.def
        end
      end
    end

    describe ".convert_disk" do
      it "should not convert the disk because it's in RAW format already" do
        @exec_helper.should_receive(:execute).with("qemu-img info 'a/disk'").and_return("image: build/appliances/x86_64/fedora/13/f13-basic/fedora-plugin/f13-basic-sda.qcow2\nfile format: raw\nvirtual size: 2.0G (2147483648 bytes)\ndisk size: 531M\ncluster_size: 65536")
        @exec_helper.should_receive(:execute).with("cp 'a/disk' 'destination'")
        @helper.convert_disk('a/disk', :raw, 'destination')
      end

      it "should convert disk from vmdk to RAW format" do
        @exec_helper.should_receive(:execute).with("qemu-img info 'a/disk'").and_return("image: build/appliances/x86_64/fedora/13/f13-basic/fedora-plugin/f13-basic-sda.vmdk\nfile format: vmdk\nvirtual size: 2.0G (2147483648 bytes)\ndisk size: 531M\ncluster_size: 65536")
        @exec_helper.should_receive(:execute).with("qemu-img convert -f vmdk -O raw 'a/disk' 'destination'")
        @helper.convert_disk('a/disk', :raw, 'destination')
      end

      it "should convert disk from raw to vmdk format using old qemu-img" do
        @exec_helper.should_receive(:execute).with("qemu-img info 'a/disk'").and_return("image: build/appliances/x86_64/fedora/13/f13-basic/fedora-plugin/f13-basic-sda.vmdk\nfile format: raw\nvirtual size: 2.0G (2147483648 bytes)\ndisk size: 531M\ncluster_size: 65536")
        @helper.should_receive(:`).with("qemu-img --help | grep '\\-6'").and_return('something')

        @exec_helper.should_receive(:execute).with("qemu-img convert -f raw -O vmdk -6 'a/disk' 'destination'")
        @helper.convert_disk('a/disk', :vmdk, 'destination')
      end

      it "should convert disk from raw to vmdk format using new qemu-img" do
        @exec_helper.should_receive(:execute).with("qemu-img info 'a/disk'").and_return("image: build/appliances/x86_64/fedora/13/f13-basic/fedora-plugin/f13-basic-sda.vmdk\nfile format: raw\nvirtual size: 2.0G (2147483648 bytes)\ndisk size: 531M\ncluster_size: 65536")
        @helper.should_receive(:`).with("qemu-img --help | grep '\\-6'").and_return('')

        @exec_helper.should_receive(:execute).with("qemu-img convert -f raw -O vmdk -o compat6 'a/disk' 'destination'")
        @helper.convert_disk('a/disk', :vmdk, 'destination')
      end

      it "should do nothing because destination already exists" do
        File.should_receive(:exists?).with('destination').and_return(true)
        @helper.convert_disk('a/disk', :vmdk, 'destination')
      end
    end
  end
end

