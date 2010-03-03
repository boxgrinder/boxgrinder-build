require 'boxgrinder/images/ec2-image'
require 'rspec-helpers/rspec-config-helper'

module BoxGrinder
  describe EC2Image do
    include RSpecConfigHelper

    before(:each) do
      @image = EC2Image.new( generate_config, generate_appliance_config, :log => Logger.new('/dev/null') )

      @exec_helper = @image.instance_variable_get(:@exec_helper)
    end

    it "should download a rpm to cache directory" do
      FileUtils.should_receive(:mkdir_p).with("sources_cache").once
      @exec_helper.should_receive(:execute).with( "wget http://rpm_location -O sources_cache/rpm_name" )
      @image.cache_rpms( 'rpm_name' => 'http://rpm_location' )
    end

    it "should get new free loop device" do
      @exec_helper.should_receive(:execute).with( "sudo losetup -f 2>&1" ).and_return(" /dev/loop1   ")
      @image.get_loop_device.should == "/dev/loop1"
    end

    it "should prepare disk for EC2 image" do
      @exec_helper.should_receive(:execute).with( "dd if=/dev/zero of=build/appliances/i386/fedora/12/valid-appliance/ec2/valid-appliance.ec2 bs=1 count=0 seek=10240M")
      @image.ec2_prepare_disk
    end

    it "should create filesystem" do
      @exec_helper.should_receive(:execute).with( "mkfs.ext3 -F build/appliances/i386/fedora/12/valid-appliance/ec2/valid-appliance.ec2")
      @image.ec2_create_filesystem
    end

    it "should mount image" do
      FileUtils.should_receive(:mkdir_p).with("mount_dir").once

      @exec_helper.should_receive(:execute).with( "sudo losetup -o 1234 /dev/loop0 disk" )
      @exec_helper.should_receive(:execute).with( "sudo mount /dev/loop0 -t ext3 mount_dir" )

      @image.mount_image("disk", "mount_dir", "/dev/loop0", "1234")
    end

    it "should sync files" do
      @exec_helper.should_receive(:execute).with( "sudo rsync -u -r -a  from/* to" )
      @image.sync_files("from", "to")
    end

  end
end
