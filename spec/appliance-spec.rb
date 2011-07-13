#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'rubygems'
require 'rspec'
require 'boxgrinder-build/appliance'
require 'ostruct'
require 'logger'

module BoxGrinder
  describe Appliance do
    def prepare_appliance(options = {}, definition_file = "#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.appl")
      @log = LogHelper.new(:level => :trace, :type => :stdout)
      @config = OpenCascade.new(:platform => :none, :delivery => :none, :force => false).merge(options)

      @plugin_manager = mock(PluginManager)

      PluginManager.stub!(:instance).and_return(@plugin_manager)

      @appliance = Appliance.new(definition_file, @config, :log => @log)
      @config = @appliance.instance_variable_get(:@config)
    end

    def prepare_appliance_config
      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:summary).and_return('asd')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '11'}))

      @appliance_config.stub!(:hardware).and_return(
          OpenCascade.new({
                              :partitions =>
                                  {
                                      '/' => {'size' => 2},
                                      '/home' => {'size' => 3},
                                  },
                              :arch => 'i686',
                              :base_arch => 'i386',
                              :cpus => 1,
                              :memory => 256,
                          })
      )

      @appliance_config
    end

    it "should create @config object without log" do
      config = Appliance.new("file", OpenCascade.new(:platform => :ec2), :log => "ALOG").instance_variable_get(:@config)

      config.size.should == 1
      config[:log].should == nil
    end
 
    describe ".validate_definition" do
      before(:each) do
        prepare_appliance
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      end

      it "should raise if we use unsupported OS" do
        PluginManager.stub(:instance).and_return(OpenCascade.new(:plugins => {:os => {:centos => {}}}))
        lambda {
          @appliance.validate_definition
        }.should raise_error(RuntimeError, "Not supported operating system selected: fedora. Make sure you have installed right operating system plugin, see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#Operating_system_plugins. Supported OSes are: centos")
      end

      it "should NOT raise if we use supported OS" do
        PluginManager.stub(:instance).and_return(OpenCascade.new(:plugins => {:os => {:fedora => {:versions => ['11']}}}))
        @appliance.validate_definition
      end
    end

    describe ".create" do
      it "should prepare appliance to build" do
        prepare_appliance

        plugin_helper = mock(PluginHelper)
        plugin_helper.should_receive(:load_plugins)

        PluginHelper.should_receive(:new).with(@config, :log => @log).and_return(plugin_helper)

        @appliance.should_receive(:read_definition)
        @appliance.should_receive(:validate_definition)
        @appliance.should_receive(:initialize_plugins)
        @appliance.should_not_receive(:remove_old_builds)
        @appliance.should_receive(:execute_plugin_chain)

        @appliance.create
      end

      it "should prepare appliance to build with removing old files" do
        prepare_appliance(:force => true)

        plugin_helper = mock(PluginHelper)
        plugin_helper.should_receive(:load_plugins)

        PluginHelper.should_receive(:new).with(@config, :log => @log).and_return(plugin_helper)

        @appliance.should_receive(:read_definition)
        @appliance.should_receive(:initialize_plugins)
        @appliance.should_receive(:validate_definition)
        @appliance.should_receive(:remove_old_builds)
        @appliance.should_receive(:execute_plugin_chain)

        @appliance.create
      end

      it "should not catch exceptions while building appliance" do
        prepare_appliance(:force => true)

        PluginHelper.should_receive(:new).with(@config, :log => @log).and_raise('something')

        lambda {
          @appliance.create
        }.should raise_error(RuntimeError, 'something')
      end
    end

    describe ".validate_definition" do
      it "should read definition with standard appliance definition file" do
        prepare_appliance

        appliance_config = ApplianceConfig.new

        appliance_helper = mock(ApplianceDefinitionHelper)
        appliance_helper.should_receive(:read_definitions).with("#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.appl")
        appliance_helper.should_receive(:appliance_configs).and_return([appliance_config])

        ApplianceDefinitionHelper.should_receive(:new).with(:log => @log).and_return(appliance_helper)

        appliance_config_helper = mock(ApplianceConfigHelper)

        appliance_config.should_receive(:clone).and_return(appliance_config)
        appliance_config.should_receive(:init_arch).and_return(appliance_config)
        appliance_config.should_receive(:initialize_paths).and_return(appliance_config)

        appliance_config_helper.should_receive(:merge).with(appliance_config).and_return(appliance_config)

        ApplianceConfigHelper.should_receive(:new).with([appliance_config]).and_return(appliance_config_helper)

        @appliance.read_definition
      end

      it "should read definition with kickstart appliance definition file" do
        prepare_appliance({}, "#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.ks")

        appliance_config = ApplianceConfig.new

        appliance_helper = mock(ApplianceDefinitionHelper)
        appliance_helper.should_receive(:read_definitions).with("#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.ks")
        appliance_helper.should_receive(:appliance_configs).and_return([])

        clazz = mock('PluginClass')

        plugin_manager = mock(PluginManager)
        plugin_manager.should_receive(:plugins).and_return({:os => {:fedora => {:class => clazz, :type => :os, :name => :fedora, :full_name => "Fedora", :versions => ["11", "12", "13", "14", "rawhide"]}}})

        plugin = mock('Plugin')
        plugin.should_receive(:respond_to?).with(:read_file).and_return(true)
        plugin.should_receive(:read_file).and_return(appliance_config)

        clazz.should_receive(:new).and_return(plugin)

        PluginManager.should_receive(:instance).and_return(plugin_manager)

        ApplianceDefinitionHelper.should_receive(:new).with(:log => @log).and_return(appliance_helper)

        appliance_config_helper = mock(ApplianceConfigHelper)

        appliance_config.should_receive(:clone).and_return(appliance_config)
        appliance_config.should_receive(:init_arch).and_return(appliance_config)
        appliance_config.should_receive(:initialize_paths).and_return(appliance_config)

        appliance_config_helper.should_receive(:merge).with(appliance_config).and_return(appliance_config)

        ApplianceConfigHelper.should_receive(:new).with([appliance_config]).and_return(appliance_config_helper)

        @appliance.read_definition
      end

      it "should read definition with kickstart appliance definition file and fail because there was no plugin able to read .ks" do
        prepare_appliance({}, "#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.ks")

        appliance_helper = mock(ApplianceDefinitionHelper)
        appliance_helper.should_receive(:read_definitions).with("#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.ks")
        appliance_helper.should_receive(:appliance_configs).and_return([])

        plugin_manager = mock(PluginManager)
        plugin_manager.should_receive(:plugins).and_return({:os => {}})


        PluginManager.should_receive(:instance).and_return(plugin_manager)

        ApplianceDefinitionHelper.should_receive(:new).with(:log => @log).and_return(appliance_helper)

        lambda {
          @appliance.read_definition
        }.should raise_error(ValidationError, "Couldn't read appliance definition file: jeos-f13.ks.")
      end
    end

    it "should remove old builds" do
      prepare_appliance
      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

      FileUtils.should_receive(:rm_rf).with("build/path")
      @appliance.remove_old_builds
    end

    describe ".execute_plugin_chain" do
      before(:each) do
        prepare_appliance
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      end

      it "should not fail when plugin chain is empty" do
        @appliance.instance_variable_set(:@plugin_chain, [])
        @appliance.execute_plugin_chain
      end

      it "should execute the whole plugin chain" do
        @appliance.instance_variable_set(:@plugin_chain, [{:plugin => :plugin1, :param => 'definition'}, {:plugin => :plugin2}, {:plugin => :plugin3}])

        @appliance.should_receive(:execute_plugin).ordered.with(:plugin1, 'definition')
        @appliance.should_receive(:execute_plugin).ordered.with(:plugin2, nil)
        @appliance.should_receive(:execute_plugin).ordered.with(:plugin3, nil)

        @appliance.execute_plugin_chain
      end
    end

    describe ".initialize_plugins" do
      it "should prepare the plugin chain to create an appliance and convert it to VMware format" do
        prepare_appliance(:platform => :vmware)
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

        os_plugin = mock("OSPlugin")
        platform_plugin = mock("PlatformPlugin", :deliverables => OpenCascade.new(:disk => 'a/disk.vmdk'))

        @plugin_manager.should_receive(:initialize_plugin).with(:os, :fedora).and_return([os_plugin, "os_plugin_info"])
        @plugin_manager.should_receive(:initialize_plugin).with(:platform, :vmware).and_return([platform_plugin, "platform_plugin_info"])
        @plugin_manager.should_not_receive(:initialize_plugin).with(:delivery, anything)

        os_plugin.should_receive(:init).with(@config, @appliance_config, "os_plugin_info", :log => @log)
        platform_plugin.should_receive(:init).with(@config, @appliance_config, "platform_plugin_info", :log => @log, :previous_plugin => os_plugin)

        @appliance.initialize_plugins

        @appliance.plugin_chain.size.should == 2
        @appliance.plugin_chain.last[:plugin].deliverables.should == {:disk=>"a/disk.vmdk"}
      end

      it "should prepare the plugin chain to create an appliance and convert it to VMware format and deliver to S3" do
        prepare_appliance(:platform => :vmware, :delivery => :s3)
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

        os_plugin = mock("OSPlugin")
        platform_plugin = mock("PlatformPlugin")
        delivery_plugin = mock("DeliveryPlugin", :deliverables => {})

        @plugin_manager.should_receive(:initialize_plugin).with(:os, :fedora).and_return([os_plugin, "os_plugin_info"])
        @plugin_manager.should_receive(:initialize_plugin).with(:platform, :vmware).and_return([platform_plugin, "platform_plugin_info"])
        @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :s3).and_return([delivery_plugin, "delivery_plugin_info"])

        os_plugin.should_receive(:init).with(@config, @appliance_config, "os_plugin_info", :log => @log)
        platform_plugin.should_receive(:init).with(@config, @appliance_config, "platform_plugin_info", :log => @log, :previous_plugin => os_plugin)
        delivery_plugin.should_receive(:init).with(@config, @appliance_config, "delivery_plugin_info", :log => @log, :previous_plugin => platform_plugin, :type => :s3)

        @appliance.initialize_plugins

        @appliance.plugin_chain.size.should == 3
        @appliance.plugin_chain.last[:plugin].deliverables.size.should == 0
      end

      it "should prepare the plugin chain to create an appliance and without conversion deliver to S3" do
        prepare_appliance(:delivery => :s3)
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

        os_plugin = mock("OSPlugin")
        delivery_plugin = mock("DeliveryPlugin")

        @plugin_manager.should_receive(:initialize_plugin).with(:os, :fedora).and_return([os_plugin, "os_plugin_info"])
        @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :s3).and_return([delivery_plugin, "delivery_plugin_info"])
        @plugin_manager.should_not_receive(:initialize_plugin).with(:platform, anything)

        os_plugin.should_receive(:init).with(@config, @appliance_config, "os_plugin_info", :log => @log)
        delivery_plugin.should_receive(:init).with(@config, @appliance_config, "delivery_plugin_info", :log => @log, :previous_plugin => os_plugin, :type => :s3)

        @appliance.initialize_plugins
      end
    end

    describe ".execute_plugin" do
      before(:each) do
        prepare_appliance
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      end

      it "should not execute the plugin because deliverable already exists" do
        plugin = mock('APlugin', :deliverables_exists? => true, :plugin_info => {:name => :ec2, :type => :platform})

        @appliance.execute_plugin(plugin)
      end

      it "should execute the plugin" do
        plugin = mock('APlugin', :deliverables_exists? => false, :plugin_info => {:name => :ec2, :type => :platform})
        plugin.should_receive(:run).with(:s3)

        @appliance.execute_plugin(plugin, :s3)
      end
    end

    context "preparations" do
      it "should return true if we have selected a platform" do
        prepare_appliance(:platform => :vmware)
        @appliance.platform_selected?.should == true
      end

      it "should return false if we haven't selected a platform" do
        prepare_appliance
        @appliance.platform_selected?.should == false
      end

      it "should return true if we have selected a delivery" do
        prepare_appliance(:delivery => :s3)
        @appliance.delivery_selected?.should == true
      end

      it "should return false if we haven't selected a delivery" do
        prepare_appliance
        @appliance.delivery_selected?.should == false
      end
    end
  end
end
