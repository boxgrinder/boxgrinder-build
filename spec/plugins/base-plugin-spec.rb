require 'boxgrinder-build/plugins/base-plugin'
require 'rspec/rspec-config-helper'

module BoxGrinder
  describe BasePlugin do
    include RSpecConfigHelper

    before(:all) do
      @arch = `uname -m`.chomp.strip
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

      deliverables = @plugin.instance_variable_get(:@deliverables)

      deliverables.disk.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp/name"
    end

    it "should register a metadata deliverable" do
      @plugin.register_deliverable(:a_name => 'a_path')

      deliverables = @plugin.instance_variable_get(:@deliverables)

      deliverables.size.should == 1
      deliverables.a_name.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp/a_path"
    end

    it "should register multiple other deliverables" do
      @plugin.register_deliverable(:a_name => 'a_path', :a_second_name => 'a_path_too')

      deliverables = @plugin.instance_variable_get(:@deliverables)

      deliverables.size.should == 2
      deliverables.a_name.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp/a_path"
      deliverables.a_second_name.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp/a_path_too"
    end

    it "should have a valid path to tmp directory" do
      @plugin.instance_variable_get(:@dir).tmp.should == "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp"
    end

    it "should check if deliverables exists and return true" do
      @plugin.register_deliverable(:disk => "disk")
      @plugin.register_deliverable(:abc => "def")
      @plugin.register_deliverable(:file => "a/path")

      File.should_receive(:exists?).exactly(3).times.with(any_args()).and_return(true)

      @plugin.deliverables_exists?.should == true
    end

    it "should check if deliverables exists and return false" do
      @plugin.register_deliverable(:disk => "disk")
      @plugin.register_deliverable(:abc => "def")
      @plugin.register_deliverable(:file => "a/path")

      File.should_receive(:exists?).once.with(any_args()).and_return(true)
      File.should_receive(:exists?).once.with(any_args()).and_return(false)
      File.should_not_receive(:exists?)

      @plugin.deliverables_exists?.should == false
    end

    it "should run the plugin" do
      @plugin.register_deliverable(:disk => "disk")

      FileUtils.should_receive(:rm_rf).with("build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp")
      FileUtils.should_receive(:mkdir_p).with("build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp")

      @plugin.should_receive( :execute ).with('a', 3)

      FileUtils.should_receive(:mv).with("build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp/disk", "build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/disk")
      FileUtils.should_receive(:rm_rf).with("build/appliances/#{@arch}/fedora/11/full/plugin_name-plugin/tmp")

      @plugin.run('a', 3)
    end

    it "should register a supported os" do
      @plugin.register_supported_os( 'fedora', ['12', '13'] )

      oses = @plugin.instance_variable_get(:@supported_oses)

      oses.size.should == 1
      oses['fedora'].size.should == 2
      oses['fedora'].should == ['12', '13']
    end

    it "should return that the OS is supported" do
      @plugin.register_supported_os( 'fedora', ['12', '13'] )

      @plugin.instance_variable_get(:@appliance_config).os.name = 'fedora'
      @plugin.instance_variable_get(:@appliance_config).os.version = '12'

      @plugin.is_supported_os?.should == true
    end

    it "should return that the OS is not supported" do
      @plugin.register_supported_os( 'fedora', ['1223'] )

      @plugin.instance_variable_get(:@appliance_config).os.name = 'fedora'
      @plugin.instance_variable_get(:@appliance_config).os.version = '12'

      @plugin.is_supported_os?.should == false
    end

    it "should return supported os string" do
      @plugin.register_supported_os( 'fedora', ['12', '13'] )
      @plugin.register_supported_os( 'centos', ['5'] )

      @plugin.supported_oses.should == "fedora (versions: 12, 13), centos (versions: 5)"
    end

    it "should set default config value" do
      @plugin.set_default_config_value( 'key', 'avalue' )

      @plugin.instance_variable_get(:@plugin_config)['key'].should == 'avalue'
    end

    it "should read plugin config" do
      @plugin.instance_variable_set(:@config_file, "configfile")

      File.should_receive(:exists?).with('configfile').and_return(true)
      YAML.should_receive(:load_file).with('configfile').and_return('abcdef')

      @plugin.read_plugin_config

      @plugin.instance_variable_get(:@plugin_config).should == 'abcdef'
    end

    it "should read plugin config and raise an exception" do
      @plugin.instance_variable_set(:@config_file, "configfile")

      File.should_receive(:exists?).with('configfile').and_return(true)
      YAML.should_receive(:load_file).with('configfile').and_raise('something')

      begin
        @plugin.read_plugin_config
        raise "Should raise"
      rescue => e
        e.message.should == "An error occurred while reading configuration file 'configfile' for BoxGrinder::BasePlugin. Is it a valid YAML file?"
      end
    end
  end
end
