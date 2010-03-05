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

    it "should install repos" do
      image = RAWImage.new( generate_config, generate_appliance_config( "#{RSPEC_BASE_LOCATION}/rspec-src/appliances/repo.appl" ), { :log => @log })

      guestfs_mock = mock("GuestFS")
      guestfs_mock.should_receive(:sh).with("echo [cirras]\nname=cirras\nenabled=1\ngpgcheck=0\nbaseurl=http://repo.boxgrinder.org/packages/fedora/12/RPMS/#{@arch} > /etc/yum.repos.d/cirras.repo")

      image.install_repos( guestfs_mock )
    end
  end
end
