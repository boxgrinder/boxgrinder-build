require 'boxgrinder-build/helpers/appliance-customize-helper'
require 'rspec/rspec-config-helper'

module BoxGrinder
  describe ApplianceCustomizeHelper do
    include RSpecConfigHelper

    before(:each) do
      @helper = ApplianceCustomizeHelper.new(generate_config, generate_appliance_config, 'a/disk', :log => Logger.new('/dev/null'))

      @log = @helper.instance_variable_get(:@log)
    end

    it "should properly prepare guestfs for customization" do

      guestfs_helper = mock('guestfs_helper')
      guestfs = mock('guestfs')
      guestfs_helper.should_receive(:run).and_return(guestfs_helper)
      guestfs_helper.should_receive(:guestfs).and_return(guestfs)
      guestfs_helper.should_receive(:clean_close)

      GuestFSHelper.should_receive(:new).with('a/disk', :log =>  @log ).and_return(guestfs_helper)

      @helper.customize do |gf, gf_helper|
        gf_helper.should  == guestfs_helper
        gf.should         == guestfs
      end
    end
  end
end
