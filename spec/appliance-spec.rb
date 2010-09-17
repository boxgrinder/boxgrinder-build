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

      @options = options
      @log = Logger.new('/dev/null')

      @plugin_manager = mock( PluginManager )

      PluginManager.stub!(:instance).and_return( @plugin_manager )

      @appliance = Appliance.new( "#{File.dirname( __FILE__ )}/rspec/src/appliances/jeos-f13.appl", :log => @log, :options => @options )
    end

    before(:each) do
      prepare_appliance
    end

    it "should prepare appliance to build" do
      @appliance.should_receive(:read_and_validate_definition)
      @appliance.should_not_receive(:remove_old_builds)
      @appliance.should_receive(:execute_plugin_chain)

      @appliance.create
    end

    it "should prepare appliance to build with removing old files" do
      prepare_appliance( OpenStruct.new( :force => true ) )

      @appliance.should_receive(:read_and_validate_definition)
      @appliance.should_receive(:remove_old_builds)
      @appliance.should_receive(:execute_plugin_chain)

      @appliance.create
    end

    it "should read and validate definition" do
      appliance_config = ApplianceConfig.new

      appliance_helper = mock(ApplianceHelper)
      appliance_helper.should_receive(:read_definitions).with( "#{File.dirname( __FILE__ )}/rspec/src/appliances/jeos-f13.appl" ).and_return([{}, appliance_config])

      ApplianceHelper.should_receive(:new).with( :log => @log ).and_return(appliance_helper)

      appliance_config_helper = mock(ApplianceConfigHelper)

      appliance_config.should_receive(:clone).and_return(appliance_config)
      appliance_config.should_receive(:init_arch).and_return(appliance_config)
      appliance_config.should_receive(:initialize_paths).and_return(appliance_config)

      appliance_config_helper.should_receive(:merge).with( appliance_config ).and_return( appliance_config )

      ApplianceConfigHelper.should_receive(:new).with( {} ).and_return( appliance_config_helper )

      appliance_config_validator = mock(ApplianceConfigValidator)
      appliance_config_validator.should_receive(:validate)

      ApplianceConfigValidator.should_receive(:new).with( appliance_config ).and_return(appliance_config_validator)

      @appliance.read_and_validate_definition
    end

    it "should remove old builds" do
      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )
      FileUtils.should_receive(:rm_rf).with("build/appliances/#{@arch}/fedora/11/full")
      @appliance.remove_old_builds
    end

    it "should build base appliance" do
      plugin_helper = mock(PluginHelper)
      plugin_helper.should_receive(:load_plugins)

      PluginHelper.should_receive( :new ).with( :options => @options, :log => @log ).and_return( plugin_helper )

      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )

      os_plugin = mock('FedoraPlugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables_exists?).and_return(false)
      os_plugin.should_receive(:run)
      os_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})

      @plugin_manager.should_receive(:plugins).and_return( { :os => "something" } )
      @plugin_manager.should_receive(:initialize_plugin).once.with(:os, :fedora).and_return([ os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name  => "Fedora", :versions   => ["11", "12", "13", "rawhide"] } ] )

      @appliance.execute_plugin_chain
    end

    it "should not build base appliance because deliverable already exists" do
      plugin_helper = mock(PluginHelper)
      plugin_helper.should_receive(:load_plugins)

      PluginHelper.should_receive( :new ).with( :options => @options, :log => @log ).and_return( plugin_helper )

      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )

      os_plugin = mock('FedoraPlugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables_exists?).and_return(true)
      os_plugin.should_not_receive(:run)
      os_plugin.should_receive(:deliverables).and_return({ :disk => 'abc'})

      @plugin_manager.should_receive(:plugins).and_return( { :os => "something" } )
      @plugin_manager.should_receive(:initialize_plugin).once.with(:os, :fedora).and_return([ os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name  => "Fedora", :versions   => ["11", "12", "13", "rawhide"] } ] )

      @appliance.execute_plugin_chain
    end

    it "should build appliance and convert it to VMware format" do
      prepare_appliance( OpenStruct.new({ :platform => :vmware }) )

      plugin_helper = mock(PluginHelper)
      plugin_helper.should_receive(:load_plugins)

      PluginHelper.should_receive( :new ).with( :options => @options, :log => @log ).and_return( plugin_helper )

      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )
      @appliance.should_receive( :execute_os_plugin ).and_return( {} )

      platform_plugin = mock('VMware Plugin')
      platform_plugin.should_receive(:init)
      platform_plugin.should_receive(:deliverables_exists?).and_return(false)
      platform_plugin.should_receive(:run)
      platform_plugin.should_receive(:deliverables).and_return({ :disk => 'abc' })

      @plugin_manager.should_receive(:plugins).and_return( { :platform => "something" } )
      @plugin_manager.should_receive(:initialize_plugin).once.with(:platform, :vmware).and_return([ platform_plugin, {:class => Appliance, :type => :platform, :name => :vmware, :full_name  => "VMware"} ]  )

      @appliance.execute_plugin_chain
    end

    it "should build appliance and convert it to VMware format because deliverable already exists" do
      prepare_appliance( OpenStruct.new({ :platform => :vmware }) )

      plugin_helper = mock(PluginHelper)
      plugin_helper.should_receive(:load_plugins)

      PluginHelper.should_receive( :new ).with( :options => @options, :log => @log ).and_return( plugin_helper )

      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )
      @appliance.should_receive( :execute_os_plugin ).and_return( {} )

      platform_plugin = mock('VMware Plugin')
      platform_plugin.should_receive(:init)
      platform_plugin.should_receive(:deliverables_exists?).and_return(true)
      platform_plugin.should_not_receive(:run)
      platform_plugin.should_receive(:deliverables).and_return({ :disk => 'abc' })

      @plugin_manager.should_receive(:plugins).and_return( { :platform => "something" } )
      @plugin_manager.should_receive(:initialize_plugin).once.with(:platform, :vmware).and_return([ platform_plugin, {:class => Appliance, :type => :platform, :name => :vmware, :full_name  => "VMware"} ]  )

      @appliance.execute_plugin_chain
    end

    it "should build appliance, convert it to EC2 format and deliver it using S3 ami type" do
      prepare_appliance( OpenStruct.new({ :platform => :ec2, :delivery => :ami }) )

      plugin_helper = mock(PluginHelper)
      plugin_helper.should_receive(:load_plugins)

      PluginHelper.should_receive( :new ).with( :options => @options, :log => @log ).and_return( plugin_helper )

      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )
      @appliance.should_receive( :execute_os_plugin ).and_return( { :abc => 'def'} )
      @appliance.should_receive( :execute_platform_plugin ).with( { :abc => 'def'} ).and_return( { :def => 'ghi'} )

      delivery_plugin = mock('S3 Plugin')
      delivery_plugin.should_receive(:init)
      delivery_plugin.should_receive(:run).with(:ami)

      @plugin_manager.should_receive(:plugins).and_return( { :delivery => "something" } )
      @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :ami).and_return([ delivery_plugin, {:class => Appliance, :type => :delivery, :name => :s3, :full_name  => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami]} ] )

      @appliance.execute_plugin_chain
    end

    it "should build appliance, convert it to EC2 format and deliver it using delivery plugin with only one delivery type" do
      prepare_appliance( OpenStruct.new({ :platform => :ec2, :delivery => :same }) )

      plugin_helper = mock(PluginHelper)
      plugin_helper.should_receive(:load_plugins)

      PluginHelper.should_receive( :new ).with( :options => @options, :log => @log ).and_return( plugin_helper )

      @appliance.instance_variable_set(:@appliance_config, generate_appliance_config )
      @appliance.should_receive( :execute_os_plugin ).and_return( { :abc => 'def'} )
      @appliance.should_receive( :execute_platform_plugin ).with( { :abc => 'def'} ).and_return( { :def => 'ghi'} )

      delivery_plugin = mock('S3 Plugin')
      delivery_plugin.should_receive(:init)
      delivery_plugin.should_receive(:run).with(no_args())

      @plugin_manager.should_receive(:plugins).and_return( { :delivery => "something" } )
      @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :same).and_return([ delivery_plugin, {:class => Appliance, :type => :delivery, :name => :same, :full_name  => "A plugin"} ] )

      @appliance.execute_plugin_chain
    end
  end
end
