require 'boxgrinder-build/plugins/platform/vmware/vmware-plugin'
require 'rspec-helpers/rspec-config-helper'
require 'rbconfig'

module BoxGrinder
  describe VMwarePlugin do
    include RSpecConfigHelper

    before(:all) do
      @arch = RbConfig::CONFIG['host_cpu']
    end

    def prepare_image
      params = OpenStruct.new
      params.base_vmdk = "../src/base.vmdk"
      params.base_vmx  = "../src/base.vmx"

      @config           = generate_config( params )
      @appliance_config = generate_appliance_config

      @plugin = VMwarePlugin.new.init( @config, @appliance_config, :log => Logger.new('/dev/null') )

      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
    end

    it "should calculate good CHS value for 1GB disk" do
      c, h, s, total_sectors = VMwarePlugin.new.init( generate_config, generate_appliance_config ).generate_scsi_chs(1)

      c.should == 512
      h.should == 128
      s.should == 32
      total_sectors.should == 2097152
    end

    it "should calculate good CHS value for 40GB disk" do
      c, h, s, total_sectors = VMwarePlugin.new.init( generate_config, generate_appliance_config ).generate_scsi_chs(40)

      c.should == 5221
      h.should == 255
      s.should == 63
      total_sectors.should == 83886080
    end

    it "should calculate good CHS value for 160GB disk" do
      c, h, s, total_sectors = VMwarePlugin.new.init( generate_config, generate_appliance_config ).generate_scsi_chs(160)

      c.should == 20886
      h.should == 255
      s.should == 63
      total_sectors.should == 335544320
    end

    it "should change vmdk data (vmfs)" do
      prepare_image

      vmdk_image = @plugin.change_vmdk_values("vmfs")

      vmdk_image.scan(/^createType="(.*)"\s?$/).to_s.should == "vmfs"

      disk_attributes = vmdk_image.scan(/^RW (.*) (.*) "(.*).raw" (.*)\s?$/)[0]

      disk_attributes[0].should == "10485760" # 5GB
      disk_attributes[1].should == "VMFS"
      disk_attributes[2].should == "full"
      disk_attributes[3].should == ""

      vmdk_image.scan(/^ddb.geometry.cylinders = "(.*)"\s?$/).to_s.should == "652"
      vmdk_image.scan(/^ddb.geometry.heads = "(.*)"\s?$/).to_s.should == "255"
      vmdk_image.scan(/^ddb.geometry.sectors = "(.*)"\s?$/).to_s.should == "63"

      vmdk_image.scan(/^ddb.virtualHWVersion = "(.*)"\s?$/).to_s.should == "4"
    end

    it "should change vmdk data (flat)" do
      prepare_image

      vmdk_image = @plugin.change_vmdk_values("monolithicFlat")

      vmdk_image.scan(/^createType="(.*)"\s?$/).to_s.should == "monolithicFlat"

      disk_attributes = vmdk_image.scan(/^RW (.*) (.*) "(.*).raw" (.*)\s?$/)[0]

      disk_attributes[0].should == "10485760" # 5GB
      disk_attributes[1].should == "FLAT"
      disk_attributes[2].should == "full"
      disk_attributes[3].should == "0"

      vmdk_image.scan(/^ddb.geometry.cylinders = "(.*)"\s?$/).to_s.should == "652"
      vmdk_image.scan(/^ddb.geometry.heads = "(.*)"\s?$/).to_s.should == "255"
      vmdk_image.scan(/^ddb.geometry.sectors = "(.*)"\s?$/).to_s.should == "63"

      vmdk_image.scan(/^ddb.virtualHWVersion = "(.*)"\s?$/).to_s.should == "3"
    end

    it "should change vmx data" do
      prepare_image

      vmx_file = @plugin.change_common_vmx_values

      vmx_file.scan(/^guestOS = "(.*)"\s?$/).to_s.should == (@arch == "x86_64" ? "otherlinux-64" : "linux")
      vmx_file.scan(/^displayName = "(.*)"\s?$/).to_s.should == "full"
      vmx_file.scan(/^annotation = "(.*)"\s?$/).to_s.scan(/^A full appliance definition | Version: 1\.0 | Built by: BoxGrinder 1\.0\.0/).should_not == nil
      vmx_file.scan(/^guestinfo.vmware.product.long = "(.*)"\s?$/).to_s.should == "full"
      vmx_file.scan(/^guestinfo.vmware.product.url = "(.*)"\s?$/).to_s.should == "http://www.jboss.org/stormgrind/projects/boxgrinder.html"
      vmx_file.scan(/^numvcpus = "(.*)"\s?$/).to_s.should == "1"
      vmx_file.scan(/^memsize = "(.*)"\s?$/).to_s.should == "256"
      vmx_file.scan(/^log.fileName = "(.*)"\s?$/).to_s.should == "full.log"
      vmx_file.scan(/^scsi0:0.fileName = "(.*)"\s?$/).to_s.should == "full.vmdk"
    end

    it "should build personal image" do
      prepare_image

      File.should_receive(:open).once.with("build/appliances/#{@arch}/fedora/11/full/vmware/full-personal.vmx", "w")
      File.should_receive(:open).once.with("build/appliances/#{@arch}/fedora/11/full/vmware/full-personal.vmdk", "w")

      @plugin.build_vmware_personal
    end

    it "should build enterprise image" do
      prepare_image

      @plugin.should_receive(:change_common_vmx_values).with(no_args()).and_return("")

      File.should_receive(:open).once.with("build/appliances/#{@arch}/fedora/11/full/vmware/full-enterprise.vmx", "w")
      File.should_receive(:open).once.with("build/appliances/#{@arch}/fedora/11/full/vmware/full-enterprise.vmdk", "w")

      @plugin.build_vmware_enterprise
    end

    it "should convert image to vmware" do
      prepare_image

      @appliance_config.post.vmware.push("one", "two", "three")

      @exec_helper.should_receive(:execute).with( "cp a/base/image/path.raw build/appliances/#{@arch}/fedora/11/full/vmware/full.raw" )
      @plugin.should_receive(:build_vmware_enterprise).with(no_args())
      @plugin.should_receive(:build_vmware_personal).with(no_args())

      guestfs_mock = mock("GuestFS")

      @plugin.should_receive(:customize).with("build/appliances/#{@arch}/fedora/11/full/vmware/full.raw").and_yield(guestfs_mock, nil)

      guestfs_mock.should_receive(:sh).once.ordered.with("one")
      guestfs_mock.should_receive(:sh).once.ordered.with("two")
      guestfs_mock.should_receive(:sh).once.ordered.with("three")

      @plugin.execute( 'a/base/image/path.raw' )
    end

#    it "should customize image" do
#      prepare_image
#
#      customize_helper_mock = mock("ApplianceCustomizeHelper")
#      ApplianceCustomizeHelper.should_receive(:new).with( @config, @appliance_config, "build/appliances/#{@arch}/fedora/12/valid-appliance/vmware/valid-appliance-sda.raw" ).and_return(customize_helper_mock)
#      customize_helper_mock.should_receive(:customize).with(no_args())
#
#      @plugin.customize
#    end

    
#    it "should install vmware tools" do
#      prepare_image
#
#      customize_helper_mock = mock("ApplianceCustomizeHelper")
#      customize_helper_mock.should_receive(:install_packages).once.with("build/appliances/#{@arch}/fedora/12/valid-appliance/vmware/valid-appliance-sda.raw", {:packages=>{:yum=>["kmod-open-vm-tools"]}, :repos=>["http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-stable.noarch.rpm", "http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-stable.noarch.rpm"]})
#
#      @plugin.install_vmware_tools( customize_helper_mock )
#    end
  end
end
