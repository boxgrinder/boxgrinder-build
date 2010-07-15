require 'boxgrinder-build/plugins/base-plugin'
require 'rspec/rspec-config-helper'
require 'rbconfig'

module BoxGrinder
  describe BasePlugin do
    include RSpecConfigHelper

    before(:all) do
      @arch = RbConfig::CONFIG['host_cpu']
    end

    before(:each) do
      @plugin = BasePlugin.new
      @plugin.init( generate_config, generate_appliance_config, :plugin_info => { :name => :plugin_name })
    end

    it "should be initialized after running init method" do
      @plugin.instance_variable_get(:@initialized).should == true
    end

    it "should register a disk deliverable" do
      @plugin.register_deliverable(:disk => "name")
      @plugin.deliverables.disk.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/name"
    end

    it "should register a metadata deliverable" do
      @plugin.register_deliverable(:a_name => 'a_path')
      @plugin.deliverables.size.should == 1
      @plugin.deliverables.a_name.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/a_path"
    end

    it "should register multiple other deliverables" do
      @plugin.register_deliverable(:a_name => 'a_path', :a_second_name => 'a_path_too')
      @plugin.deliverables.size.should == 2
      @plugin.deliverables.a_name.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/a_path"
      @plugin.deliverables.a_second_name.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/a_path_too"
    end

    it "should have a valid path to tmp directory" do
      @plugin.instance_variable_get(:@dir).tmp.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp"
    end
  end
end
