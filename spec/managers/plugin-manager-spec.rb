require 'boxgrinder-build/managers/plugin-manager'

module BoxGrinder
  describe PluginManager do

    before(:each) do
      @manager = PluginManager.instance
    end

    it "should register simple plugin" do
      @manager.register_plugin( { :class => PluginManager, :type => :delivery, :name => :abc, :full_name  => "Amazon Simple Storage Service (Amazon S3)" } )

      @manager.plugins[:delivery].size.should == 1
      @manager.plugins[:delivery][:abc][:class].should == PluginManager
    end

    it "should register plugin with many types" do
      @manager.register_plugin( { :class => PluginManager, :type => :delivery, :name => :s3, :full_name  => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami] } )

      @manager.plugins[:delivery].size.should == 4
      @manager.plugins[:delivery][:abc][:class].should == PluginManager
      @manager.plugins[:delivery][:ami][:class].should == PluginManager
      @manager.plugins[:delivery][:s3][:class].should == PluginManager
      @manager.plugins[:delivery][:cloudfront][:class].should == PluginManager
    end
  end
end
