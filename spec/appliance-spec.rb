require 'boxgrinder-build/appliance'
require 'rspec/rspec-config-helper'
require 'ostruct'

module BoxGrinder
  describe Appliance do
    include RSpecConfigHelper

    before(:all) do
      @arch = `uname -m`.chomp.strip
    end

    def prepare_appliance( options = OpenStruct.new )
      options.name      = 'boxgrinder'
      options.version   = '1.0'

      @appliance = Appliance.new( "#{File.dirname( __FILE__ )}/rspec/src/appliances/jeos-f13.appl", :log => Logger.new('/dev/null'), :options => options )
    end

    before(:each) do
      prepare_appliance
    end

    it "should create only base image" do
      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      plugin_manager_first_call = mock('PluginManagerOne')
      plugin_manager_first_call.should_receive(:plugins).and_return({})

      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)

      os_plugin = mock('OS Plugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables_exists?).and_return(false)
      os_plugin.should_receive(:run)
      os_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})

      plugin_manager_second_call = mock('PluginManagerTwo')
      plugin_manager_second_call.should_receive(:initialize_plugin).with(:os, :fedora).and_return([ os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name  => "Fedora", :versions   => ["11", "12", "13", "rawhide"] } ] )

      PluginManager.should_receive(:instance).and_return(plugin_manager_second_call)

      @appliance.create
    end

    it "should build appliance and convert it to VMware format" do
      prepare_appliance( OpenStruct.new({ :platform => :vmware }) )

      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      os_plugin_output = {}

      @appliance.should_receive(:execute_os_plugin).and_return(os_plugin_output)

      plugin_manager_first_call = mock('PluginManagerOne')
      plugin_manager_first_call.should_receive(:plugins).and_return({})

      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)

      platform_plugin = mock('VMware Plugin')
      platform_plugin.should_receive(:init)
      platform_plugin.should_receive(:deliverables_exists?).and_return(false)
      platform_plugin.should_receive(:run)
      platform_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})

      plugin_manager_second_call = mock('PluginManagerTwo')
      plugin_manager_second_call.should_receive(:initialize_plugin).with(:platform, :vmware).and_return([ platform_plugin, {:class => Appliance, :type => :platform, :name => :vmware, :full_name  => "VMware"} ] )

      PluginManager.should_receive(:instance).and_return(plugin_manager_second_call)

      @appliance.create
    end

    it "should build appliance, convert it to EC2 format and deliver it using S3 ami type" do
      prepare_appliance( OpenStruct.new({ :platform => :ec2, :delivery => :ami }) )

      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      os_plugin_output = { :abc => 'def'}
      platform_plugin_output = { :abc => 'def'}

      @appliance.should_receive(:execute_os_plugin).and_return(os_plugin_output)
      @appliance.should_receive(:execute_platform_plugin).and_return(platform_plugin_output)

      plugin_manager_first_call = mock('PluginManagerOne')
      plugin_manager_first_call.should_receive(:plugins).and_return({})

      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)

      delivery_plugin = mock('S3 Plugin')
      delivery_plugin.should_receive(:init)
      delivery_plugin.should_receive(:run).with(:ami)

      plugin_manager_second_call = mock('PluginManagerTwo')
      plugin_manager_second_call.should_receive(:initialize_plugin).with(:delivery, :ami).and_return([ delivery_plugin, {:class => Appliance, :type => :delivery, :name => :s3, :full_name  => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami]} ] )

      PluginManager.should_receive(:instance).and_return(plugin_manager_second_call)

      @appliance.create
    end
    it "should build appliance, convert it to vmware format and deliver it using sftp ami type" do
      prepare_appliance( OpenStruct.new({ :platform => :vmware, :delivery => :sftp }) )

      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      os_plugin_output = { :abc => 'def'}
      platform_plugin_output = { :abc => 'def'}

      @appliance.should_receive(:execute_os_plugin).and_return(os_plugin_output)
      @appliance.should_receive(:execute_platform_plugin).and_return(platform_plugin_output)

      plugin_manager_first_call = mock('PluginManagerOne')
      plugin_manager_first_call.should_receive(:plugins).and_return({})

      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)

      delivery_plugin = mock('S3 Plugin')
      delivery_plugin.should_receive(:init)
      delivery_plugin.should_receive(:run).with(no_args)

      plugin_manager_second_call = mock('PluginManagerTwo')
      plugin_manager_second_call.should_receive(:initialize_plugin).with(:delivery, :sftp).and_return([ delivery_plugin, {:class => Appliance, :type => :delivery, :name => :sftp, :full_name  => "SSH File Transfer Protocol"} ] )

      PluginManager.should_receive(:instance).and_return(plugin_manager_second_call)

      @appliance.create
    end

    it "should remove previous build when force is specified" do
      prepare_appliance( OpenStruct.new( :force => true ) )

      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      @appliance.should_receive(:execute_os_plugin).and_return(nil)
      @appliance.should_receive(:execute_platform_plugin).and_return(nil)
      @appliance.should_receive(:execute_delivery_plugin).and_return(nil)

      FileUtils.should_receive(:rm_rf).with("build/appliances/#{@arch}/fedora/13/jeos-f13")

      @appliance.create
    end

    it "should not execute plugins when deliverables exists" do
      prepare_appliance( OpenStruct.new({ :platform => :vmware }) )

      validator = mock(ApplianceConfigValidator)
      validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with(any_args).and_return(validator)

      os_plugin = mock('OS Plugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables_exists?).and_return(true)
      os_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})

      plugin_manager_first_call = mock('PluginManagerOne')
      plugin_manager_first_call.should_receive(:plugins).and_return({})

      PluginManager.should_receive(:instance).and_return(plugin_manager_first_call)

      plugin_manager_second_call = mock('PluginManagerTwo')
      plugin_manager_second_call.should_receive(:initialize_plugin).with(:os, :fedora).and_return([ os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name  => "Fedora", :versions   => ["11", "12", "13", "rawhide"] } ] )

      PluginManager.should_receive(:instance).and_return(plugin_manager_second_call)

      platform_plugin = mock('Platform Plugin')
      platform_plugin.should_receive(:init)
      platform_plugin.should_receive(:deliverables_exists?).and_return(true)
      platform_plugin.should_receive(:deliverables).and_return({ :disk => 'def'})

      platform_plugin_manager_second_call = mock('PlatformPluginManagerOne')
      platform_plugin_manager_second_call.should_receive(:initialize_plugin).with(:platform, :vmware).and_return([ platform_plugin, {:class => Appliance, :type => :platform, :name => :vmware, :full_name  => "VMware"} ] )

      PluginManager.should_receive(:instance).and_return(platform_plugin_manager_second_call)

      @appliance.create
    end
  end
end
