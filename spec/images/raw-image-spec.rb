require 'boxgrinder/images/raw-image'
require 'rspec-helpers/rspec-config-helper'
require 'rbconfig'

module BoxGrinder
  describe RAWImage do
    include RSpecConfigHelper

    before(:all) do
      @log  = Logger.new('/dev/null')
      @arch = RbConfig::CONFIG['host_cpu']
    end

    before(:each) do
      @image  = RAWImage.new( generate_config, generate_appliance_config, { :log => @log })

      @config       = @image.instance_variable_get(:@config)
      @exec_helper  = @image.instance_variable_get(:@exec_helper)
      @log          = @image.instance_variable_get(:@log)
    end

    it "should install repos" do
      image = RAWImage.new( generate_config, generate_appliance_config( "#{RSPEC_BASE_LOCATION}/rspec-src/appliances/repo.appl" ), { :log => @log })

      guestfs_mock = mock("GuestFS")
      guestfs_mock.should_receive(:sh).with("echo '[cirras]\nname=cirras\nenabled=1\ngpgcheck=0\nbaseurl=http://repo.boxgrinder.org/packages/fedora/12/RPMS/#{@arch}' > /etc/yum.repos.d/cirras.repo")

      image.install_repos( guestfs_mock )
    end

    it "should install version files" do
      guestfs_mock = mock("GuestFS")

      guestfs_mock.should_receive(:sh).with("echo 'BOXGRINDER_VERSION=1.0.0' > /etc/sysconfig/boxgrinder")
      guestfs_mock.should_receive(:sh).with("echo 'APPLIANCE_NAME=valid-appliance' >> /etc/sysconfig/boxgrinder")

      @image.install_version_files( guestfs_mock )
    end

    it "should install motd" do
      guestfs_mock = mock("GuestFS")

      guestfs_mock.should_receive(:upload).with("#{@config.dir.base}/src/motd.init", "/etc/init.d/motd")
      guestfs_mock.should_receive(:sh).with("sed -i s/#VERSION#/'1.0'/ /etc/init.d/motd")
      guestfs_mock.should_receive(:sh).with("sed -i s/#APPLIANCE#/'valid-appliance appliance'/ /etc/init.d/motd")
      guestfs_mock.should_receive(:sh).with("/bin/chmod +x /etc/init.d/motd")
      guestfs_mock.should_receive(:sh).with("/sbin/chkconfig --add motd")

      @image.set_motd( guestfs_mock )
    end

    it "should change configuration using augeas" do
      guestfs_mock = mock("GuestFS")

      guestfs_mock.should_receive(:aug_init).with("/", 0)
      guestfs_mock.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      guestfs_mock.should_receive(:aug_save).with(no_args())

      @image.change_configuration( guestfs_mock )
    end

    it "should execute post build operations" do
      guestfs_helper_mock = mock("GuestFSHelper")
      guestfs_mock = mock("GuestFS")

      GuestFSHelper.should_receive(:new).with("build/appliances/#{@arch}/fedora/12/valid-appliance/raw/valid-appliance/valid-appliance-sda.raw").and_return(guestfs_helper_mock)
      guestfs_helper_mock.should_receive(:guestfs).once.and_return(guestfs_mock)

      @image.should_receive(:change_configuration).once.ordered.with(guestfs_mock)
      @image.should_receive(:set_motd).once.ordered.with(guestfs_mock)
      @image.should_receive(:install_version_files).once.ordered.with(guestfs_mock)
      @image.should_receive(:install_repos).once.ordered.with(guestfs_mock)

      @image.should_not_receive(:sh)

      guestfs_mock.should_receive(:close).once

      @image.do_post_build_operations
    end

    it "should build RAW image" do
      @exec_helper.should_receive(:execute).once.ordered.with("sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t /tmp/dir_root/build/tmp --cache=rpms_cache/#{@arch}/fedora/12 --config build/appliances/#{@arch}/fedora/12/valid-appliance/raw/valid-appliance.ks -o build/appliances/#{@arch}/fedora/12/valid-appliance/raw --name valid-appliance --vmem 256 --vcpu 1")
      @exec_helper.should_receive(:execute).once.ordered.with("sudo chmod 777 build/appliances/#{@arch}/fedora/12/valid-appliance/raw/valid-appliance")
      @exec_helper.should_receive(:execute).once.ordered.with("sudo chmod 666 build/appliances/#{@arch}/fedora/12/valid-appliance/raw/valid-appliance/valid-appliance-sda.raw")
      @exec_helper.should_receive(:execute).once.ordered.with("sudo chmod 666 build/appliances/#{@arch}/fedora/12/valid-appliance/raw/valid-appliance/valid-appliance.xml")

      @image.build_raw_image
    end
  end
end
