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

require 'boxgrinder-build/appliance'
require 'ostruct'
require 'logger'

module BoxGrinder
  describe Appliance do
    def prepare_appliance(options = {}, definition_file = "#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.appl")
      @log = LogHelper.new(:level => :trace, :type => :stdout)
      @config = OpenCascade[:platform => :none, :delivery => :none, :force => false, 
        :change_to_user => false, :uid => 501, :gid => 501, 
        :dir => {:root => '/', :build => 'build'}].merge(options)

      @plugin_manager = mock(PluginManager)

      PluginManager.stub!(:instance).and_return(@plugin_manager)

      @appliance = Appliance.new(definition_file, @config, :log => @log)
      @config = @appliance.instance_variable_get(:@config)
    end

    def prepare_appliance_config
      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade[{:build => 'build/path'}])
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:summary).and_return('asd')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade[{:name => 'fedora', :version => '11'}])

      @appliance_config.stub!(:hardware).and_return(
          OpenCascade[{
                              :partitions =>
                                  {
                                      '/' => {'size' => 2},
                                      '/home' => {'size' => 3},
                                  },
                              :arch => 'i686',
                              :base_arch => 'i386',
                              :cpus => 1,
                              :memory => 256,
                          }]
      )

      @appliance_config
    end

    it "should create @config object without log" do
      config = Appliance.new("file", OpenCascade[:platform => :ec2], :log => "ALOG").instance_variable_get(:@config)

      config.size.should == 1
      config[:log].should == nil
    end
 
    describe ".validate_definition" do
      before(:each) do
        prepare_appliance
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      end

      it "should raise if we use unsupported OS" do
        PluginManager.stub(:instance).and_return(OpenCascade[:plugins => {:os => {:centos => {}}}])
        lambda {
          @appliance.validate_definition
        }.should raise_error(RuntimeError, "Unsupported operating system selected: fedora. Make sure you have installed right operating system plugin, see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#Operating_system_plugins. Supported OSes are: centos")
      end

      it "should NOT raise if we use supported OS" do
        PluginManager.stub(:instance).and_return(OpenCascade[:plugins => {:os => {:fedora => {:versions => ['11']}}}])
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

        UserSwitcher.stub(:change_user)

        @plugin1, @plugin2, @plugin3 = 3.times.map{|i| mock(i).as_null_object}

        @p_chain = [{:plugin => @plugin1, :param => 'definition'},
          {:plugin => @plugin2}, {:plugin => @plugin3}]
      end

      it "should not fail when plugin chain is empty" do
        @appliance.instance_variable_set(:@plugin_chain, [])
        @appliance.execute_plugin_chain
      end

      it "should execute the whole plugin chain" do
        @appliance.instance_variable_set(:@plugin_chain, @p_chain) 
       
        @appliance.should_receive(:execute_plugin).with(@plugin1, 'definition')
        @appliance.should_receive(:execute_plugin).with(@plugin2, nil)
        @appliance.should_receive(:execute_plugin).with(@plugin3, nil)
          
        @appliance.execute_plugin_chain
      end   

      context "when executing without change_user" do
        before(:each) do
          @config.stub(:change_to_user).and_return(false) # default
        end
      
        it "should not switch users" do
          @appliance.instance_variable_set(:@plugin_chain, [])
          
          UserSwitcher.should_not_receive(:change_user)
          @appliance.execute_plugin_chain
        end
      end

      context "when executing with change_user" do
        before(:each) do
          @config.stub(:change_to_user).and_return(true)
          @plugin1.stub_chain(:plugin_info, :[]).and_return(true)
          @plugin2.stub_chain(:plugin_info, :[]).and_return(false)
          @plugin3.stub_chain(:plugin_info, :[]).and_return(false)

          @appliance.instance_variable_set(:@plugin_chain, @p_chain)
        end

        it "should switch users if the plugin requires root, but not for those that do not" do
          UserSwitcher.should_receive(:change_user).with(0, 0)
          UserSwitcher.should_receive(:change_user).twice.with(501, 501)
          
          @appliance.execute_plugin_chain
        end
      end
    end

    describe ".initialize_plugins" do
      let(:os_plugin){ mock("OSPlugin") }

      let(:os_plugin_info_mock){ mock('os_plugin_info_mock', :[] => 'os').as_null_object }
      let(:platform_plugin_info_mock){ mock('platform_plugin_info_mock', :[] => 'plat').as_null_object }
      let(:delivery_plugin_info_mock){ mock('delivery_plugin_info_mock', :[] => 'deliver').as_null_object }

      let(:platform_plugin){ mock("PlatformPlugin", :deliverables => OpenCascade[:disk => 'a/disk.vmdk']) }
      let(:delivery_plugin){ mock("DeliveryPlugin", :deliverables => {}) }

      it "should prepare the plugin chain to create an appliance and convert it to VMware format" do
        prepare_appliance(:platform => :vmware)
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

        @plugin_manager.should_receive(:initialize_plugin).with(:os, :fedora).and_return([os_plugin, os_plugin_info_mock])
        @plugin_manager.should_receive(:initialize_plugin).with(:platform, :vmware).and_return([platform_plugin, platform_plugin_info_mock])
        @plugin_manager.should_not_receive(:initialize_plugin).with(:delivery, anything)

        os_plugin.should_receive(:init).with(@config, @appliance_config, os_plugin_info_mock, :log => @log)
        platform_plugin.should_receive(:init).with(@config, @appliance_config, platform_plugin_info_mock, :log => @log, :previous_plugin => os_plugin)

        @appliance.initialize_plugins

        @appliance.plugin_chain.size.should == 2
        @appliance.plugin_chain.last[:plugin].deliverables.should == {:disk=>"a/disk.vmdk"}
      end

      it "should prepare the plugin chain to create an appliance and convert it to VMware format and deliver to S3" do
        prepare_appliance(:platform => :vmware, :delivery => :s3)
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

        @plugin_manager.should_receive(:initialize_plugin).with(:os, :fedora).and_return([os_plugin, os_plugin_info_mock])
        @plugin_manager.should_receive(:initialize_plugin).with(:platform, :vmware).and_return([platform_plugin, platform_plugin_info_mock])
        @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :s3).and_return([delivery_plugin, delivery_plugin_info_mock])

        os_plugin.should_receive(:init).with(@config, @appliance_config, os_plugin_info_mock, :log => @log)
        platform_plugin.should_receive(:init).with(@config, @appliance_config, platform_plugin_info_mock, :log => @log, :previous_plugin => os_plugin)
        delivery_plugin.should_receive(:init).with(@config, @appliance_config, delivery_plugin_info_mock, :log => @log, :previous_plugin => platform_plugin, :type => :s3)

        @appliance.initialize_plugins

        @appliance.plugin_chain.size.should == 3
        @appliance.plugin_chain.last[:plugin].deliverables.size.should == 0
      end

      it "should prepare the plugin chain to create an appliance and without conversion deliver to S3" do
        prepare_appliance(:delivery => :s3)
        @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

        @plugin_manager.should_receive(:initialize_plugin).with(:os, :fedora).and_return([os_plugin, os_plugin_info_mock])
        @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :s3).and_return([delivery_plugin, delivery_plugin_info_mock])
        @plugin_manager.should_not_receive(:initialize_plugin).with(:platform, anything)

        os_plugin.should_receive(:init).with(@config, @appliance_config, os_plugin_info_mock, :log => @log)
        delivery_plugin.should_receive(:init).with(@config, @appliance_config, delivery_plugin_info_mock, :log => @log, :previous_plugin => os_plugin, :type => :s3)

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
