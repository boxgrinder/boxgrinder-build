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

require 'rubygems'
require 'rspec'
require 'boxgrinder-build/plugins/platform/virtualbox/virtualbox-plugin'
require 'hashery/opencascade'
require 'spec/rspec-plugin-helper.rb'

module BoxGrinder
  describe VirtualBoxPlugin do
    def prepare_image(options = {})
      @config = mock('Config')
      @config.stub!(:version).and_return('0.1.2')
      @config.stub!(:platform_config).and_return({})
      @config.stub!(:[]).with(:plugins).and_return({})

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:summary).and_return('asd')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '14'}))
      @appliance_config.stub!(:post).and_return(OpenCascade.new({:virtualbox => []}))

      @appliance_config.stub!(:hardware).and_return(
          OpenCascade.new({
                              :partitions =>
                                  {
                                      '/' => {'size' => 2},
                                      '/home' => {'size' => 3},
                                  },
                              :arch => 'i686',
                              :base_arch => 'i386',
                              :cpus => 1,
                              :memory => 256,
                          })
      )

      @plugin = RSpecPluginHelper.new(VirtualBoxPlugin).prepare(@config, @appliance_config,
        :previous_plugin => OpenCascade.new(:deliverables => {:disk => 'a/base/image/path.raw'}),
        :plugin_info => {:class => BoxGrinder::VirtualBoxPlugin, :type => :platform, :name => :virtualbox, :full_name => "VirtualBox"}
      )

      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @image_helper = @plugin.instance_variable_get(:@image_helper)
      @log = @plugin.instance_variable_get(:@log)
    end

    describe ".build_virtualbox" do
      before(:each) do
        prepare_image
      end

      it "should build virtualbox image on new qemu-img" do
        @image_helper.should_receive(:convert_disk).with("a/base/image/path.raw", :vmdk, "build/path/virtualbox-plugin/tmp/full.vmdk")

        @plugin.build_virtualbox
      end

      it "should build virtualbox image on old qemu-img" do
        @image_helper.should_receive(:convert_disk).with("a/base/image/path.raw", :vmdk, "build/path/virtualbox-plugin/tmp/full.vmdk")

        @plugin.build_virtualbox
      end
    end

    describe ".is_os_old?" do
      it "should return false for fedora 14" do
        prepare_image
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '14'}))
        @plugin.is_os_old?.should == false
      end

      it "should return false for rhel 6" do
        prepare_image
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'rhel', :version => '6'}))
        @plugin.is_os_old?.should == false
      end

      it "should return true for centos 5" do
        prepare_image
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'centos', :version => '5'}))
        @plugin.is_os_old?.should == true
      end
    end

    describe ".customize" do
      it "should customize the image" do
        prepare_image

        @appliance_config.post['virtualbox'] = ["one", "two", "three"]

        guestfs_helper_mock = mock("GuestFSHelper")

#        @image_helper.should_receive(:customize).with("build/path/virtualbox-plugin/tmp/full.vmdk").and_yield(guestfs_mock, guestfs_helper_mock)

        guestfs_helper_mock.should_receive(:sh).once.ordered.with("one", :arch => 'i686')
        guestfs_helper_mock.should_receive(:sh).once.ordered.with("two", :arch => 'i686')
        guestfs_helper_mock.should_receive(:sh).once.ordered.with("three", :arch => 'i686')

        @plugin.customize(guestfs_helper_mock)
      end
    end

    describe ".execute" do
      it "should execute the conversion" do
        prepare_image

        @plugin.should_receive(:build_virtualbox)

        @image_helper.should_not_receive(:customize)
        @plugin.should_not_receive(:recreate_kernel)
        @plugin.should_not_receive(:customize)

        @plugin.execute
      end

      it "should execute the conversion with post operations" do
        prepare_image

        @appliance_config.post['virtualbox'] = ["one", "two", "three"]

        @plugin.should_receive(:build_virtualbox)

        guestfs_mock = mock("GuestFS")
        guestfs_helper_mock = mock("GuestFSHelper")

        @image_helper.should_receive(:customize).with(["build/path/virtualbox-plugin/tmp/full.vmdk"]).and_yield(guestfs_mock, guestfs_helper_mock)

        @plugin.should_not_receive(:recreate_kernel)
        @plugin.should_receive(:customize).with(guestfs_helper_mock)

        @plugin.execute
      end

      it "should execute the conversion with post operations for rhel 5" do
        prepare_image

        @appliance_config.post['virtualbox'] = ["one", "two", "three"]
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'rhel', :version => '5'}))

        @plugin.should_receive(:build_virtualbox)

        guestfs_mock = mock("GuestFS")
        guestfs_helper_mock = mock("GuestFSHelper")

        @image_helper.should_receive(:customize).with(["build/path/virtualbox-plugin/tmp/full.vmdk"]).and_yield(guestfs_mock, guestfs_helper_mock)

        @plugin.should_receive(:recreate_kernel).with(guestfs_mock)
        @plugin.should_receive(:customize).with(guestfs_helper_mock)

        @plugin.execute
      end

      it "should not customize the image if no commands are specified and the appliance os version is old" do
        prepare_image

        @plugin.should_receive(:build_virtualbox)
        @plugin.should_receive(:is_os_old?).and_return(false)
        @image_helper.should_not_receive(:customize)

        @plugin.execute
      end
    end

    describe ".recreate_kernel" do
      it "should recreate the kernel" do
        prepare_image

        guestfs_mock = mock("GuestFS")
        linux_helper_mock = mock(LinuxHelper)
        linux_helper_mock.should_receive(:recreate_kernel_image).with(guestfs_mock, ['ahci'])

        LinuxHelper.should_receive(:new).with(:log => @log).and_return(linux_helper_mock)

        @plugin.recreate_kernel(guestfs_mock)
      end
    end
  end
end
