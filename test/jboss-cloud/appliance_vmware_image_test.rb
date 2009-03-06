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

require 'test/unit'

require 'jboss-cloud/config'
require 'jboss-cloud/appliance-vmx-image'

class ApplianceVMwareImageTest < Test::Unit::TestCase
  def setup
    @src_dir = "../../../src"
    @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
  end
  
  def self.generate_config( dir_src = @src_dir )
    JBossCloud::Config.new("JBoss-Cloud", "1.0.0", nil, "/tmp/dir_rpms_cache", "/tmp/dir_src_cache" , "/tmp/dir_root" , "/tmp/dir_top" , "/tmp/dir_build" , "/tmp/dir_specs" , "/tmp/dir_appliances" , dir_src )
  end
  
  def self.generate_appliance_config
    appliance_config = JBossCloud::ApplianceConfig.new("really-good-appliance", "i386", "fedora", "10")
    
    appliance_config.disk_size = 2048
    appliance_config.summary = "this is a summary"
    appliance_config.network_name = "NAT"
    appliance_config.vcpu = "1"
    appliance_config.mem_size = "1024"
    
    appliance_config
  end
  
  def test_generate_valid_disk_size_for_1GB_disk
    vmx_image = JBossCloud::ApplianceVMXImage.new( ApplianceVMwareImageTest.generate_config, ApplianceVMwareImageTest.generate_appliance_config )
    
    c, h, s = vmx_image.generate_scsi_chs(1024)
    
    assert_equal(512, c)
    assert_equal(128, h)
    assert_equal(32, s)
  end
  
  def test_generate_valid_disk_size_for_40GB_disk
    vmx_image = JBossCloud::ApplianceVMXImage.new( ApplianceVMwareImageTest.generate_config, ApplianceVMwareImageTest.generate_appliance_config )
    
    c, h, s = vmx_image.generate_scsi_chs(1024 * 40)
    
    assert_equal(5221, c)
    assert_equal(255, h)
    assert_equal(63, s)
  end
  
  def test_generate_valid_disk_size_for_160GB_disk
    vmx_image = JBossCloud::ApplianceVMXImage.new( ApplianceVMwareImageTest.generate_config, ApplianceVMwareImageTest.generate_appliance_config )
    
    c, h, s = vmx_image.generate_scsi_chs(1024 * 160)
    
    assert_equal(20886, c)
    assert_equal(255, h)
    assert_equal(63, s)
  end
  
  def test_change_vmdk_data_vmfs
    vmx_image = JBossCloud::ApplianceVMXImage.new( ApplianceVMwareImageTest.generate_config, ApplianceVMwareImageTest.generate_appliance_config )
    
    vmdk_image = vmx_image.change_vmdk_values("vmfs")
    
    assert_equal(vmdk_image.match(/^createType="(.*)"\s?$/)[1], "vmfs")
    
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[1], "4194304")
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[2], "VMFS")
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[3], "really-good-appliance")
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[4], "")
    
    assert_equal(vmdk_image.match(/^ddb.geometry.cylinders = "(.*)"\s?$/)[1], "261")
    assert_equal(vmdk_image.match(/^ddb.geometry.heads = "(.*)"\s?$/)[1], "255")
    assert_equal(vmdk_image.match(/^ddb.geometry.sectors = "(.*)"\s?$/)[1], "63")
    
    assert_equal(vmdk_image.match(/^ddb.virtualHWVersion = "(.*)"\s?$/)[1], "4")
  end
  
  def test_change_vmdk_data_flat
    vmx_image = JBossCloud::ApplianceVMXImage.new( ApplianceVMwareImageTest.generate_config, ApplianceVMwareImageTest.generate_appliance_config )
    
    vmdk_image = vmx_image.change_vmdk_values("monolithicFlat")
    
    assert_equal(vmdk_image.match(/^createType="(.*)"\s?$/)[1], "monolithicFlat")
    
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[1], "4194304")
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[2], "FLAT")
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[3], "really-good-appliance")
    assert_equal(vmdk_image.match(/^RW (.*) (.*) "(.*)-sda.raw" (.*)\s?$/)[4], "0")
    
    assert_equal(vmdk_image.match(/^ddb.geometry.cylinders = "(.*)"\s?$/)[1], "261")
    assert_equal(vmdk_image.match(/^ddb.geometry.heads = "(.*)"\s?$/)[1], "255")
    assert_equal(vmdk_image.match(/^ddb.geometry.sectors = "(.*)"\s?$/)[1], "63")
    
    assert_equal(vmdk_image.match(/^ddb.virtualHWVersion = "(.*)"\s?$/)[1], "3")
  end
  
  def test_change_vmx_data
    vmx_image = JBossCloud::ApplianceVMXImage.new( ApplianceVMwareImageTest.generate_config, ApplianceVMwareImageTest.generate_appliance_config )
    
    vmx_file = vmx_image.change_common_vmx_values
    
    guestOS = @current_arch == "x86_64" ? "otherlinux-64" : "linux" 
    
    assert_equal(vmx_file.match(/^guestOS = "(.*)"\s?$/)[1], guestOS)
    assert_equal(vmx_file.match(/^displayName = "(.*)"\s?$/)[1], "really-good-appliance")
    assert_equal(vmx_file.match(/^annotation = "(.*)"\s?$/)[1], "this is a summary | Version: 1.0.0")
    assert_equal(vmx_file.match(/^guestinfo.vmware.product.long = "(.*)"\s?$/)[1], "really-good-appliance")
    assert_equal(vmx_file.match(/^guestinfo.vmware.product.url = "(.*)"\s?$/)[1], "http://oddthesis.org")
    assert_equal(vmx_file.match(/^numvcpus = "(.*)"\s?$/)[1], "1")
    assert_equal(vmx_file.match(/^memsize = "(.*)"\s?$/)[1], "1024")
    assert_equal(vmx_file.match(/^log.fileName = "(.*)"\s?$/)[1], "really-good-appliance.log")
    assert_equal(vmx_file.match(/^scsi0:0.fileName = "(.*)"\s?$/)[1], "really-good-appliance.vmdk")
    assert_equal(vmx_file.match(/^ethernet0.networkName = "(.*)"\s?$/)[1], "NAT")   
  end
  
  
end