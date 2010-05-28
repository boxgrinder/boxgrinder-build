require 'boxgrinder-build/plugins/os/base/rpm-based-os-plugin'
require 'rspec-helpers/rspec-config-helper'

module BoxGrinder
  describe RPMBasedOSPlugin do
    include RSpecConfigHelper

    before(:each) do
      @plugin = RPMBasedOSPlugin.new.init(generate_config, generate_appliance_config, :log => Logger.new('/dev/null'))

      @config             = @plugin.instance_variable_get(:@config)
      @appliance_config   = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper        = @plugin.instance_variable_get(:@exec_helper)
      @log                = @plugin.instance_variable_get(:@log)
    end

    it "should install repos" do
      guestfs = mock("guestfs")

      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/cirras.repo", "[cirras]\nname=cirras\nenabled=1\ngpgcheck=0\nbaseurl=http://repo.boxgrinder.org/packages/fedora/11/RPMS/i386\n", 0)
      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/abc.repo", "[abc]\nname=abc\nenabled=1\ngpgcheck=0\nbaseurl=http://abc\nmirrorlist=http://repo.boxgrinder.org/packages/fedora/11/RPMS/i386\n", 0)
      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/boxgrinder-f11-testing-i386.repo", "[boxgrinder-f11-testing-i386]\nname=boxgrinder-f11-testing-i386\nenabled=1\ngpgcheck=0\nmirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-testing-f11&arch=i386\n", 0)

      @plugin.install_repos( guestfs )
    end

    it "should not install ephemeral repos" do
      @plugin = RPMBasedOSPlugin.new.init(generate_config, generate_appliance_config( "#{RSPEC_BASE_LOCATION}/rspec-src/appliances/ephemeral-repo.appl" ), :log => Logger.new('/dev/null'))

      guestfs = mock("guestfs")

      guestfs.should_receive(:write_file).once.with("/etc/yum.repos.d/boxgrinder-f12-testing-i386.repo", "[boxgrinder-f12-testing-i386]\nname=boxgrinder-f12-testing-i386\nenabled=1\ngpgcheck=0\nmirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-testing-f12&arch=i386\n", 0)

      @plugin.install_repos( guestfs )
    end
  end
end

