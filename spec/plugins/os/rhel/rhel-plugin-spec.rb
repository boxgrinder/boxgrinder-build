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

require 'boxgrinder-build/plugins/os/rhel/rhel-plugin'
require 'boxgrinder-core/astruct'

module BoxGrinder
  describe RHELPlugin do
    before(:each) do
      @config = mock('Config')
      @config.stub!(:os_config).and_return({})
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('rhel').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(AStruct.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'rhel', :version => '6'}))

      @plugin = RHELPlugin.new.init(@config, @appliance_config, {:class => BoxGrinder::RHELPlugin, :type => :os, :name => :rhel, :full_name => "Red Hat Enterprise Linux", :versions => ['5', '6']}, :log => LogHelper.new(:level => :trace, :type => :stdout))

      @config = @plugin.instance_variable_get(:@config)
      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @linux_helper = @plugin.instance_variable_get(:@linux_helper)
      @log = @plugin.instance_variable_get(:@log)
    end

    describe ".normalize_packages" do
      it "should add @core to package list" do
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'rhel', :version => '5'}))

        packages = []

        @plugin.normalize_packages(packages)

        packages.size.should == 8
        packages[0].should == '@core'
        packages[1].should == 'curl'
        packages[2].should == 'grub'
        packages[3].should == 'kernel'
        packages[4].should == 'system-config-securitylevel-tui'
        packages[5].should == 'util-linux'
        packages[6].should == 'setarch'
        packages[7].should == 'sudo'
      end

      it "should not add kernel package if kernel-xen is already choose" do
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'rhel', :version => '5'}))

        packages = ['kernel-xen']

        @plugin.normalize_packages(packages)

        packages.size.should == 8
        packages[0].should == 'kernel-xen'
        packages[1].should == '@core'
        packages[2].should == 'curl'
        packages[3].should == 'grub'
        packages[4].should == 'system-config-securitylevel-tui'
        packages[5].should == 'util-linux'
        packages[6].should == 'setarch'
        packages[7].should == 'sudo'
      end

      it "should not add default packages for RHEL 6" do
        packages = []

        @plugin.normalize_packages(packages)

        packages.size.should == 5
        packages[0].should == '@core'
        packages[1].should == 'curl'
        packages[2].should == 'grub'
        packages[3].should == 'kernel'
        packages[4].should == 'system-config-firewall-base'
      end
    end

    describe ".execute" do
      it "should recreate the kernel and add some modules to RHEL 5 with normal kernel" do
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'rhel', :version => '5'}))

        @appliance_config.stub!(:packages).and_return([])

        @plugin.should_receive(:normalize_packages).ordered

        guestfs = mock('guestfs')
        guestfs_helper = mock('guestfshelper')

        @plugin.should_receive(:build_with_appliance_creator).ordered.and_yield(guestfs, guestfs_helper)

        @linux_helper.should_receive(:recreate_kernel_image).with(guestfs, ['mptspi', 'virtio_pci', 'virtio_blk'])

        @plugin.execute('file')
      end

      it "should NOT recreate the kernel and add some modules to RHEL 5 if kernel-xen is choosen" do
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'rhel', :version => '5'}))

        @appliance_config.stub!(:packages).and_return(['kernel-xen'])

        @plugin.should_receive(:normalize_packages).ordered

        guestfs = mock('guestfs')
        guestfs_helper = mock('guestfshelper')

        @plugin.should_receive(:build_with_appliance_creator).ordered.and_yield(guestfs, guestfs_helper)

        @linux_helper.should_not_receive(:recreate_kernel_image)

        @plugin.execute('file')
      end

      it "should build the appliance" do
        @appliance_config.should_receive(:packages).and_return(['kernel'])

        @plugin.should_receive(:normalize_packages).ordered
        @plugin.should_receive(:build_with_appliance_creator).ordered

        @linux_helper.should_not_receive(:recreate_kernel_image)

        @plugin.execute('file')
      end

      it "should link /boot/grub/grub.conf to /etc/grub.conf" do
        guestfs = mock("GuestFS")
        guestfs.should_receive(:ln_sf).with("/boot/grub/grub.conf", "/etc/grub.conf")
        @plugin.link_grubconf(guestfs)
      end

      it "should write the kernel sysconfig file with an appropriate default kernel" do
        guestfs = mock("GuestFS")

        guestfs.should_receive(:write_file).with("/etc/sysconfig/kernel", "DEFAULTKERNEL=kernel\nUPDATEDEFAULT=yes\n", 0)
        @plugin.write_kernel_sysconfig(guestfs, [])

        guestfs.should_receive(:write_file).with("/etc/sysconfig/kernel", "DEFAULTKERNEL=kernel-xen\nUPDATEDEFAULT=yes\n", 0)
        @plugin.write_kernel_sysconfig(guestfs, ['kernel-xen'])

        guestfs.should_receive(:write_file).with("/etc/sysconfig/kernel", "DEFAULTKERNEL=kernel-ml\nUPDATEDEFAULT=yes\n", 0)
        @plugin.write_kernel_sysconfig(guestfs, ['kernel-ml'])

        guestfs.should_receive(:write_file).with("/etc/sysconfig/kernel", "DEFAULTKERNEL=kernel-pae\nUPDATEDEFAULT=yes\n", 0)
        @plugin.write_kernel_sysconfig(guestfs, ['kernel-pae'])
      end
    end
  end
end
