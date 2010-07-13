require 'boxgrinder-build/appliance'
require 'rspec/rspec-config-helper'
require 'rbconfig'
require 'ostruct'

module BoxGrinder
  describe Appliance do
    include RSpecConfigHelper

    before(:all) do
      @arch = RbConfig::CONFIG['host_cpu']
    end

    before(:each) do
      @appliance = Appliance.new( "#{File.dirname( __FILE__ )}/rspec/src/appliances/jeos-f13.appl", :log => Logger.new('/dev/null'), :options => OpenStruct.new({ :name => 'BoxGrinder', :version => 'best' }) )
      #@plugin.init( generate_config, generate_appliance_config, :plugin_info => { :name => :plugin_name })
    end

    it "should create only base image" do
      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      plugin_manager_first_call = mock(PluginManager)
      plugin_manager_first_call.should_receive(:plugins).and_return({})

      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)
      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)


      os_plugin = mock('OS Plugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})
      os_plugin.should_receive(:execute)
      os_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})

      plugin_manager_first_call.should_receive(:initialize_plugin).with(:os, :fedora).and_return([ os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name  => "Fedora", :versions   => ["11", "12", "13", "rawhide"] } ] )

      @appliance.create
    end
  end
end
