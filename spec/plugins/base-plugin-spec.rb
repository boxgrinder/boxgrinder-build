require 'boxgrinder-build/plugins/base-plugin'

module BoxGrinder
  describe BasePlugin do

    before(:each) do
      @plugin = BasePlugin.new
    end

    it "should be initialized after running init method" do
      @plugin.init( nil, nil)

      @plugin.instance_variable_get(:@initialized).should == true
    end
  end
end
