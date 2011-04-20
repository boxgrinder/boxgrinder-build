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

    describe ".create" do

      it "should prepare appliance to build" do
        prepare_appliance

        plugin_helper = mock(PluginHelper)
        plugin_helper.should_receive(:load_plugins)

        PluginHelper.should_receive(:new).with(@config, :log => @log).and_return(plugin_helper)

        @appliance.should_receive(:read_definition)
        @appliance.should_receive(:validate_definition)
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
        appliance_helper.should_receive(:read_definitions).with("#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.ks").and_raise("Unknown format")

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
        appliance_helper.should_receive(:read_definitions).with("#{File.dirname(__FILE__)}/rspec/src/appliances/jeos-f13.ks").and_raise("Unknown format")

        plugin_manager = mock(PluginManager)
        plugin_manager.should_receive(:plugins).and_return({:os => {}})


        PluginManager.should_receive(:instance).and_return(plugin_manager)

        ApplianceDefinitionHelper.should_receive(:new).with(:log => @log).and_return(appliance_helper)

        lambda {
          @appliance.read_definition
        }.should raise_error("Couldn't read appliance definition file: jeos-f13.ks")
      end
    end

    it "should remove old builds" do
      prepare_appliance

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      FileUtils.should_receive(:rm_rf).with("build/path")
      @appliance.remove_old_builds
    end

    it "should build base appliance" do
      prepare_appliance

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

      os_plugin = mock('FedoraPlugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables_exists?).and_return(false)
      os_plugin.should_receive(:run)
      os_plugin.should_receive(:deliverables).and_return({:disk => 'abc'})

      @plugin_manager.should_receive(:plugins).and_return({:os => "something"})
      @plugin_manager.should_receive(:initialize_plugin).once.with(:os, :fedora).and_return([os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name => "Fedora", :versions => ["11", "12", "13", "rawhide"]}])

      @appliance.execute_plugin_chain
    end

    it "should not build base appliance because deliverable already exists" do
      prepare_appliance

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)

      os_plugin = mock('FedoraPlugin')
      os_plugin.should_receive(:init)
      os_plugin.should_receive(:deliverables_exists?).and_return(true)
      os_plugin.should_not_receive(:run)
      os_plugin.should_receive(:deliverables).and_return({:disk => 'abc'})

      @plugin_manager.should_receive(:plugins).and_return({:os => "something"})
      @plugin_manager.should_receive(:initialize_plugin).once.with(:os, :fedora).and_return([os_plugin, {:class => Appliance, :type => :os, :name => :fedora, :full_name => "Fedora", :versions => ["11", "12", "13", "rawhide"]}])

      @appliance.execute_plugin_chain
    end

    it "should build appliance and convert it to VMware format" do
      prepare_appliance(:platform => :vmware)

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      @appliance.should_receive(:execute_os_plugin).and_return({})

      platform_plugin = mock('VMware Plugin')
      platform_plugin.should_receive(:init)
      platform_plugin.should_receive(:deliverables_exists?).and_return(false)
      platform_plugin.should_receive(:run)
      platform_plugin.should_receive(:deliverables).and_return({:disk => 'abc'})

      @plugin_manager.should_receive(:plugins).and_return({:platform => "something"})
      @plugin_manager.should_receive(:initialize_plugin).once.with(:platform, :vmware).and_return([platform_plugin, {:class => Appliance, :type => :platform, :name => :vmware, :full_name => "VMware"}])

      @appliance.execute_plugin_chain
    end

    it "should build appliance and convert it to VMware format because deliverable already exists" do
      prepare_appliance(:platform => :vmware)

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      @appliance.should_receive(:execute_os_plugin).and_return({})

      platform_plugin = mock('VMware Plugin')
      platform_plugin.should_receive(:init)
      platform_plugin.should_receive(:deliverables_exists?).and_return(true)
      platform_plugin.should_not_receive(:run)
      platform_plugin.should_receive(:deliverables).and_return({:disk => 'abc'})

      @plugin_manager.should_receive(:plugins).and_return({:platform => "something"})
      @plugin_manager.should_receive(:initialize_plugin).once.with(:platform, :vmware).and_return([platform_plugin, {:class => Appliance, :type => :platform, :name => :vmware, :full_name => "VMware"}])

      @appliance.execute_plugin_chain
    end

    it "should build appliance, convert it to EC2 format and deliver it using S3 ami type" do
      prepare_appliance(:platform => :ec2, :delivery => :ami)

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      @appliance.should_receive(:execute_os_plugin).and_return({:abc => 'def'})
      @appliance.should_receive(:execute_platform_plugin).with({:abc => 'def'}).and_return({:def => 'ghi'})

      delivery_plugin = mock('S3 Plugin')
      delivery_plugin.should_receive(:init)
      delivery_plugin.should_receive(:run).with(:ami)

      @plugin_manager.should_receive(:plugins).and_return({:delivery => "something"})
      @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :ami).and_return([delivery_plugin, {:class => Appliance, :type => :delivery, :name => :s3, :full_name => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami]}])

      @appliance.execute_plugin_chain
    end

    it "should build appliance, convert it to EC2 format and deliver it using delivery plugin with only one delivery type" do
      prepare_appliance(:platform => :ec2, :delivery => :same)

      @appliance.instance_variable_set(:@appliance_config, prepare_appliance_config)
      @appliance.should_receive(:execute_os_plugin).and_return({:abc => 'def'})
      @appliance.should_receive(:execute_platform_plugin).with({:abc => 'def'}).and_return({:def => 'ghi'})

      delivery_plugin = mock('S3 Plugin')
      delivery_plugin.should_receive(:init)
      delivery_plugin.should_receive(:run).with(:same)

      @plugin_manager.should_receive(:plugins).and_return({:delivery => "something"})
      @plugin_manager.should_receive(:initialize_plugin).with(:delivery, :same).and_return([delivery_plugin, {:class => Appliance, :type => :delivery, :name => :same, :full_name => "A plugin"}])

      @appliance.execute_plugin_chain
    end
  end
end
