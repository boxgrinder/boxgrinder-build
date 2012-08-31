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

require 'boxgrinder-build/plugins/platform/vmware/vmware-plugin'
require 'boxgrinder-core/astruct'

module BoxGrinder
  describe VMwarePlugin do
    def prepare_image(plugin_config, options = {})
      @config = mock('Config')
      @config.stub!(:version).and_return('0.1.2')
      @config.stub!(:platform_config).and_return({})
      @config.stub!(:[]).with(:plugins).and_return({'vmware' => plugin_config})

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(AStruct.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:summary).and_return('asd')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'fedora', :version => '11'}))
      @appliance_config.stub!(:post).and_return(AStruct.new({:vmware => []}))

      @appliance_config.stub!(:hardware).and_return(
          AStruct.new({
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

      @plugin = RSpecPluginHelper.new(VMwarePlugin).prepare(@config, @appliance_config,
        :previous_plugin => AStruct.new(:deliverables => {:disk => 'a/base/image/path.raw'}),
        :plugin_info =>  {:class => BoxGrinder::VMwarePlugin, :type => :platform, :name => :vmware, :full_name => "VMware"}
      )

      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @image_helper = @plugin.instance_variable_get(:@image_helper)
    end

    it "should calculate good CHS value for 0.5GB disk" do
      prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

      File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 536870912))

      c, h, s, total_sectors = @plugin.generate_scsi_chs

      c.should == 512
      h.should == 64
      s.should == 32
      total_sectors.should == 1048576
    end

    it "should calculate good CHS value for 1GB disk" do
      prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

      File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 1073741824))

      c, h, s, total_sectors = @plugin.generate_scsi_chs

      c.should == 512
      h.should == 128
      s.should == 32
      total_sectors.should == 2097152
    end

    it "should calculate good CHS value for 40GB disk" do
      prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

      File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 42949672960))

      c, h, s, total_sectors = @plugin.generate_scsi_chs

      c.should == 5221
      h.should == 255
      s.should == 63
      total_sectors.should == 83886080
    end

    it "should calculate good CHS value for 160GB disk" do
      prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

      File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 171798691840))

      c, h, s, total_sectors = @plugin.generate_scsi_chs

      c.should == 20886
      h.should == 255
      s.should == 63
      total_sectors.should == 335544320
    end

    describe ".change_vmdk_values" do
      it "should change vmdk data (vmfs)" do
        prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

        File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 5368709120))

        vmdk_image = @plugin.change_vmdk_values("vmfs")

        vmdk_image.match(/^createType="(.*)"\s?$/)[1].should == "vmfs"

        disk_attributes = vmdk_image.scan(/^RW (.*) (.*) "(.*).raw" (.*)\s?$/)[0]

        disk_attributes[0].should == "10485760" # 5GB
        disk_attributes[1].should == "VMFS"
        disk_attributes[2].should == "full"
        disk_attributes[3].should == ""

        vmdk_image.match(/^ddb.geometry.cylinders = "(.*)"\s?$/)[1].should == "652"
        vmdk_image.match(/^ddb.geometry.heads = "(.*)"\s?$/)[1].should == "255"
        vmdk_image.match(/^ddb.geometry.sectors = "(.*)"\s?$/)[1].should == "63"

        vmdk_image.match(/^ddb.virtualHWVersion = "(.*)"\s?$/)[1].should == "7"
      end

      it "should change vmdk data (flat)" do
        prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

        File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 5368709120))

        vmdk_image = @plugin.change_vmdk_values("monolithicFlat")

        vmdk_image.match(/^createType="(.*)"\s?$/)[1].should == "monolithicFlat"

        disk_attributes = vmdk_image.scan(/^RW (.*) (.*) "(.*).raw" (.*)\s?$/)[0]

        disk_attributes[0].should == "10485760" # 5GB
        disk_attributes[1].should == "FLAT"
        disk_attributes[2].should == "full"
        disk_attributes[3].should == "0"

        vmdk_image.match(/^ddb.geometry.cylinders = "(.*)"\s?$/)[1].should == "652"
        vmdk_image.match(/^ddb.geometry.heads = "(.*)"\s?$/)[1].should == "255"
        vmdk_image.match(/^ddb.geometry.sectors = "(.*)"\s?$/)[1].should == "63"

        vmdk_image.match(/^ddb.virtualHWVersion = "(.*)"\s?$/)[1].should == "7"
        vmdk_image.match(/^ddb.thinProvisioned = "(.*)"\s?$/)[1].should == "0"
      end

      it "should change vmdk data (flat) enabling thin disk" do
        prepare_image({'thin_disk' => true, 'type' => 'enterprise'})

        File.should_receive(:stat).with("a/base/image/path.raw").and_return(OpenStruct.new(:size => 5368709120))

        vmdk_image = @plugin.change_vmdk_values("monolithicFlat")

        vmdk_image.match(/^ddb.thinProvisioned = "(.*)"\s?$/)[1].should == "1"
      end
    end

    it "should change vmx data" do
      prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

      vmx_file = @plugin.change_common_vmx_values
      
      vmx_file.match(/^guestOS = "(.*)"\s?$/)[1].should == "linux"
      vmx_file.match(/^displayName = "(.*)"\s?$/)[1].should == "full"

      vmx_file.match(/^annotation = "(.*)"\s?$/)[1].
        match(/^full | Version: 1\.0 | Built by: BoxGrinder 1\.0\.0/).should_not == nil
      
      vmx_file.match(/^guestinfo.vmware.product.long = "(.*)"\s?$/)[1].should == "full"
      vmx_file.match(/^guestinfo.vmware.product.url = "(.*)"\s?$/)[1].should == "http://boxgrinder.org"
      vmx_file.match(/^numvcpus = "(.*)"\s?$/)[1].should == "1"
      vmx_file.match(/^memsize = "(.*)"\s?$/)[1].should == "256"
      vmx_file.match(/^log.fileName = "(.*)"\s?$/)[1].should == "full.log"
      vmx_file.match(/^scsi0:0.fileName = "(.*)"\s?$/)[1].should == "full.vmdk"
    end

    describe ".build_vmware_personal" do
      it "should build personal thick image" do
        prepare_image({'type' => 'personal', 'thin_disk' => false})

        @exec_helper.should_receive(:execute).with("cp 'a/base/image/path.raw' 'build/path/vmware-plugin/tmp/full.raw'")
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmx", "w")
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmdk", "w")

        @plugin.build_vmware_personal
      end

      it "should build personal thin image" do
        prepare_image({'type' => 'personal', 'thin_disk' => true})

        @image_helper.should_receive(:convert_disk).with('a/base/image/path.raw', :vmdk, 'build/path/vmware-plugin/tmp/full.vmdk')
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmx", "w")

        @plugin.build_vmware_personal
      end
    end

    describe ".build_vmware_enterprise" do
      it "should build enterprise thick image" do
        prepare_image({'type' => 'enterprise', 'thin_disk' => false})

        @plugin.should_receive(:change_common_vmx_values).and_return("")
        @exec_helper.should_receive(:execute).with("cp 'a/base/image/path.raw' 'build/path/vmware-plugin/tmp/full.raw'")
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmx", "w")
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmdk", "w")

        @plugin.build_vmware_enterprise
      end

      it "should build enterprise thin image" do
        prepare_image({'type' => 'enterprise', 'thin_disk' => true})

        @plugin.should_receive(:change_common_vmx_values).and_return("")
        @exec_helper.should_receive(:execute).with("cp 'a/base/image/path.raw' 'build/path/vmware-plugin/tmp/full.raw'")
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmx", "w")
        File.should_receive(:open).once.with("build/path/vmware-plugin/tmp/full.vmdk", "w")

        @plugin.build_vmware_enterprise
      end
    end

    describe ".execute" do
      it "should convert image to vmware personal" do
        prepare_image({'type' => 'personal'})

        @plugin.should_receive(:build_vmware_personal).with(no_args())
        @plugin.should_receive(:customize_image).with(no_args())

        File.should_receive(:open)

        @plugin.execute
      end

      it "should convert image to vmware enterprise" do
        prepare_image({'type' => 'enterprise'})

        @plugin.should_receive(:build_vmware_enterprise).with(no_args())
        @plugin.should_receive(:customize_image).with(no_args())

        File.should_receive(:open)

        @plugin.execute
      end

      it "should fail because not supported format was choosen" do
        prepare_image({'type' => 'unknown'})

        @plugin.should_not_receive(:build_vmware_enterprise)
        @plugin.should_not_receive(:customize_image)

        lambda {
          @plugin.execute
        }.should raise_error(RuntimeError, "Not known VMware format specified. Available are: personal and enterprise. See http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#VMware_Platform_Plugin for more info.")
      end
    end

    describe ".customize_image" do
      it "should customize the image" do
        prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

        @appliance_config.post['vmware'] = ["one", "two", "three"]

        guestfs_mock = mock("GuestFS")
        guestfs_helper_mock = mock("GuestFSHelper")

        @image_helper.should_receive(:customize).with("build/path/vmware-plugin/tmp/full.raw").and_yield(guestfs_mock, guestfs_helper_mock)

        guestfs_helper_mock.should_receive(:sh).once.ordered.with("one", :arch => 'i686')
        guestfs_helper_mock.should_receive(:sh).once.ordered.with("two", :arch => 'i686')
        guestfs_helper_mock.should_receive(:sh).once.ordered.with("three", :arch => 'i686')

        @plugin.customize_image
      end

      it "should skip customizing the image" do
        prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

        @appliance_config.post['vmware'] = []
        @image_helper.should_not_receive(:customize)

        @plugin.customize_image
      end
    end

    it "should create a valid README file" do
      prepare_image({'thin_disk' => false, 'type' => 'enterprise'})

      file = mock(File)

      File.should_receive(:open).and_return(file)
      file.should_receive(:read).and_return("one #APPLIANCE_NAME# two")

      @plugin.create_readme.should == "one full two"
    end
  end
end
