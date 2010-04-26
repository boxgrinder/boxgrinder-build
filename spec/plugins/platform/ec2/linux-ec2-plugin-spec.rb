require 'boxgrinder-build/plugins/platform/ec2/linux-ec2-plugin'
require 'rspec-helpers/rspec-config-helper'

module BoxGrinder
  describe LinuxEC2Plugin do
    include RSpecConfigHelper

    before(:each) do
      @plugin = LinuxEC2Plugin.new.init(generate_config, generate_appliance_config, :log => Logger.new('/dev/null'))

      @config             = @plugin.instance_variable_get(:@config)
      @appliance_config   = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper        = @plugin.instance_variable_get(:@exec_helper)
      @log                = @plugin.instance_variable_get(:@log)
    end

    it "should download a rpm to cache directory" do
      FileUtils.should_receive(:mkdir_p).with("sources-cache").once
      @exec_helper.should_receive(:execute).with( "wget http://rpm_location -O sources-cache/rpm_name" )
      @plugin.cache_rpms( 'rpm_name' => 'http://rpm_location' )
    end

    it "should get new free loop device" do
      @exec_helper.should_receive(:execute).with( "sudo losetup -f 2>&1" ).and_return(" /dev/loop1   ")
      @plugin.get_loop_device.should == "/dev/loop1"
    end

    it "should prepare disk for EC2 image" do
      @exec_helper.should_receive(:execute).with( "dd if=/dev/zero of=build/appliances/#{RbConfig::CONFIG['host_cpu']}/fedora/11/full/ec2/full.ec2 bs=1 count=0 seek=10240M")
      @plugin.ec2_prepare_disk
    end

    it "should create filesystem" do
      @exec_helper.should_receive(:execute).with( "mkfs.ext3 -F build/appliances/#{RbConfig::CONFIG['host_cpu']}/fedora/11/full/ec2/full.ec2")
      @plugin.ec2_create_filesystem
    end

    it "should mount image" do
      FileUtils.should_receive(:mkdir_p).with("mount_dir").once

      @plugin.should_receive(:get_loop_device).once.and_return("/dev/loop0")
      @exec_helper.should_receive(:execute).with( "sudo losetup -o 1234 /dev/loop0 disk" )
      @exec_helper.should_receive(:execute).with( "sudo mount /dev/loop0 -t ext3 mount_dir" )

      @plugin.mount_image("disk", "mount_dir", "1234")
    end

    it "should sync files" do
      @exec_helper.should_receive(:execute).with( "sudo rsync -u -r -a  from/* to" )
      @plugin.sync_files("from", "to")
    end

    it "should create devices" do
      guestfs = mock("guestfs")

      guestfs.should_receive(:sh).once.with("/sbin/MAKEDEV -d /dev -x console")
      guestfs.should_receive(:sh).once.with("/sbin/MAKEDEV -d /dev -x null")
      guestfs.should_receive(:sh).once.with("/sbin/MAKEDEV -d /dev -x zero")

      @log.should_receive(:debug).once.with("Creating required devices...")
      @log.should_receive(:debug).once.with("Devices created.")

      @plugin.create_devices( guestfs )
    end

    it "should upload fstab" do
      guestfs = mock("guestfs")

      guestfs.should_receive(:upload).once.with(any_args(), "/etc/fstab")

      @log.should_receive(:debug).once.with("Uploading '/etc/fstab' file...")
      @log.should_receive(:debug).once.with("'/etc/fstab' file uploaded.")

      @plugin.upload_fstab( guestfs )
    end

    it "should enable networking" do
      guestfs = mock("guestfs")

      guestfs.should_receive(:sh).once.with("/sbin/chkconfig network on")
      guestfs.should_receive(:upload).once.with(any_args(), "/etc/sysconfig/network-scripts/ifcfg-eth0")

      @log.should_receive(:debug).once.with("Enabling networking...")
      @log.should_receive(:debug).once.with("Networking enabled.")

      @plugin.enable_networking( guestfs )
    end

    it "should upload rc_local" do
      guestfs   = mock("guestfs")
      tempfile  = mock("tempfile")

      Tempfile.should_receive(:new).with("rc_local").and_return(tempfile)
      File.should_receive(:read).with(any_args()).and_return("with other content")

      guestfs.should_receive(:read_file).once.ordered.with("/etc/rc.local").and_return("content ")
      tempfile.should_receive(:<<).once.ordered.with("content with other content")
      tempfile.should_receive(:flush).once.ordered
      tempfile.should_receive(:path).once.ordered.and_return("path")
      guestfs.should_receive(:upload).once.ordered.with("path", "/etc/rc.local")
      tempfile.should_receive(:close).once.ordered

      @log.should_receive(:debug).once.with("Uploading '/etc/rc.local' file...")
      @log.should_receive(:debug).once.with("'/etc/rc.local' file uploaded.")

      @plugin.upload_rc_local( guestfs )
    end

    it "should install additional packages" do
      guestfs = mock("guestfs")

      kernel_rpm = (RbConfig::CONFIG['host_cpu'] == "x86_64" ? "kernel-xen-2.6.21.7-2.fc8.x86_64.rpm" : "kernel-xen-2.6.21.7-2.fc8.i686.rpm")

      rpms = { kernel_rpm => "http://repo.oddthesis.org/packages/other/#{kernel_rpm}", "ec2-ami-tools.noarch.rpm" => "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm" }

      @plugin.should_receive(:cache_rpms).once.with(rpms)

      guestfs.should_receive(:mkdir_p).once.ordered.with("/tmp/rpms")
      guestfs.should_receive(:upload).once.ordered.with("sources-cache/#{kernel_rpm}", "/tmp/rpms/#{kernel_rpm}")
      guestfs.should_receive(:upload).once.ordered.with("sources-cache/ec2-ami-tools.noarch.rpm", "/tmp/rpms/ec2-ami-tools.noarch.rpm")
      guestfs.should_receive(:sh).once.ordered.with("rpm -Uvh --nodeps /tmp/rpms/*.rpm")
      guestfs.should_receive(:rm_rf).once.ordered.with("/tmp/rpms")

      @log.should_receive(:debug).once.ordered.with("Installing additional packages (#{kernel_rpm}, ec2-ami-tools.noarch.rpm)...")
      @log.should_receive(:debug).once.ordered.with("Additional packages installed.")

      @plugin.install_additional_packages( guestfs )
    end

    it "should change configuration" do
      guestfs = mock("guestfs")

      guestfs.should_receive(:aug_init).once.ordered.with("/", 0)
      guestfs.should_receive(:aug_set).once.ordered.with( "/files/etc/ssh/sshd_config/PasswordAuthentication", "no" )
      guestfs.should_receive(:aug_save).once.ordered

      @log.should_receive(:debug).once.ordered.with("Changing configuration files using augeas...")
      @log.should_receive(:debug).once.ordered.with("Augeas changes saved.")

      @plugin.change_configuration( guestfs )
    end

  end
end

