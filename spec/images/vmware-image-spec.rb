require 'boxgrinder/images/vmware-image'
require 'rspec-helpers/rspec-config-helper'
require 'rbconfig'

module BoxGrinder
  describe VMwareImage do
    include RSpecConfigHelper

    def prepare_image
      params = OpenStruct.new
      params.base_vmdk = "../src/base.vmdk"
      params.base_vmx  = "../src/base.vmx"

      @image = VMwareImage.new( generate_config( params ), generate_appliance_config, :log => Logger.new('/dev/null') )
    end

    it "should calculate good CHS value for 1GB disk" do
      c, h, s, total_sectors = VMwareImage.new( generate_config, generate_appliance_config ).generate_scsi_chs(1)

      c.should == 512
      h.should == 128
      s.should == 32
      total_sectors.should == 2097152
    end

    it "should calculate good CHS value for 40GB disk" do
      c, h, s, total_sectors = VMwareImage.new( generate_config, generate_appliance_config ).generate_scsi_chs(40)

      c.should == 5221
      h.should == 255
      s.should == 63
      total_sectors.should == 83886080
    end

    it "should calculate good CHS value for 160GB disk" do
      c, h, s, total_sectors = VMwareImage.new( generate_config, generate_appliance_config ).generate_scsi_chs(160)

      c.should == 20886
      h.should == 255
      s.should == 63
      total_sectors.should == 335544320
    end

    it "should change vmdk data (vmfs)" do
      prepare_image

      vmdk_image = @image.change_vmdk_values("vmfs")

      vmdk_image.scan(/^createType="(.*)"\s?$/).to_s.should == "vmfs"

      disk_attributes = vmdk_image.scan(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[0]

      disk_attributes[0].should == "2097152"
      disk_attributes[1].should == "VMFS"
      disk_attributes[2].should == "valid-appliance"
      disk_attributes[3].should == ""

      vmdk_image.scan(/^ddb.geometry.cylinders = "(.*)"\s?$/).to_s.should == "512"
      vmdk_image.scan(/^ddb.geometry.heads = "(.*)"\s?$/).to_s.should == "128"
      vmdk_image.scan(/^ddb.geometry.sectors = "(.*)"\s?$/).to_s.should == "32"

      vmdk_image.scan(/^ddb.virtualHWVersion = "(.*)"\s?$/).to_s.should == "4"
    end

    it "should change vmdk data (flat)" do
      prepare_image

      vmdk_image = @image.change_vmdk_values("monolithicFlat")

      vmdk_image.scan(/^createType="(.*)"\s?$/).to_s.should == "monolithicFlat"

      disk_attributes = vmdk_image.scan(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[0]

      disk_attributes[0].should == "2097152"
      disk_attributes[1].should == "FLAT"
      disk_attributes[2].should == "valid-appliance"
      disk_attributes[3].should == "0"

      vmdk_image.scan(/^ddb.geometry.cylinders = "(.*)"\s?$/).to_s.should == "512"
      vmdk_image.scan(/^ddb.geometry.heads = "(.*)"\s?$/).to_s.should == "128"
      vmdk_image.scan(/^ddb.geometry.sectors = "(.*)"\s?$/).to_s.should == "32"

      vmdk_image.scan(/^ddb.virtualHWVersion = "(.*)"\s?$/).to_s.should == "3"
    end

    it "should change vmx data" do
      prepare_image

      vmx_file = @image.change_common_vmx_values

      vmx_file.scan(/^guestOS = "(.*)"\s?$/).to_s.should == (RbConfig::CONFIG['host_cpu'] == "x86_64" ? "otherlinux-64" : "linux")
      vmx_file.scan(/^displayName = "(.*)"\s?$/).to_s.should == "valid-appliance"
      vmx_file.scan(/^annotation = "(.*)"\s?$/).to_s.should == "This is a summary | Version: 1.0 | Built by: BoxGrinder 1.0.0"
      vmx_file.scan(/^guestinfo.vmware.product.long = "(.*)"\s?$/).to_s.should == "valid-appliance"
      vmx_file.scan(/^guestinfo.vmware.product.url = "(.*)"\s?$/).to_s.should == "http://www.jboss.org/stormgrind/projects/boxgrinder.html"
      vmx_file.scan(/^numvcpus = "(.*)"\s?$/).to_s.should == "1"
      vmx_file.scan(/^memsize = "(.*)"\s?$/).to_s.should == "256"
      vmx_file.scan(/^log.fileName = "(.*)"\s?$/).to_s.should == "valid-appliance.log"
      vmx_file.scan(/^scsi0:0.fileName = "(.*)"\s?$/).to_s.should == "valid-appliance.vmdk"

    end
  end
end
