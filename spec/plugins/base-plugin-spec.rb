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
require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-core/helpers/log-helper'
require 'yaml'

module BoxGrinder
  describe BasePlugin do
    before(:each) do
      @config = mock('Config')
      @config.stub!(:name).and_return('BoxGrinder')
      @config.stub!(:version_with_release).and_return('0.1.2')

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '13'}))

      @log = LogHelper.new(:level => :trace, :type => :stdout)

      @plugin = BasePlugin.new
      @plugin.should_receive(:merge_plugin_config)
      @plugin.init(@config, @appliance_config, :plugin_info => {:name => :plugin_name, :full_name => "Amazon Simple Storage Service (Amazon S3)"}, :log => @log)
    end

    it "should be initialized after running init method" do
      @plugin.instance_variable_get(:@initialized).should == true
    end

    it "should register a disk deliverable" do
      @plugin.register_deliverable(:disk => "name")

      deliverables = @plugin.instance_variable_get(:@deliverables)

      deliverables.disk.should == "build/path/plugin_name-plugin/tmp/name"
    end

    it "should register a metadata deliverable" do
      @plugin.register_deliverable(:a_name => 'a_path')

      deliverables = @plugin.instance_variable_get(:@deliverables)

      deliverables.size.should == 1
      deliverables.a_name.should == "build/path/plugin_name-plugin/tmp/a_path"
    end

    it "should register multiple other deliverables" do
      @plugin.register_deliverable(:a_name => 'a_path', :a_second_name => 'a_path_too')

      deliverables = @plugin.instance_variable_get(:@deliverables)

      deliverables.size.should == 2
      deliverables.a_name.should == "build/path/plugin_name-plugin/tmp/a_path"
      deliverables.a_second_name.should == "build/path/plugin_name-plugin/tmp/a_path_too"
    end

    it "should have a valid path to tmp directory" do
      @plugin.instance_variable_get(:@dir).tmp.should == "build/path/plugin_name-plugin/tmp"
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

    describe ".run" do
      it "should run the plugin" do
        @plugin.register_supported_os('fedora', ['12', '13'])
        @plugin.register_deliverable(:disk => "disk")

        FileUtils.should_receive(:rm_rf).with("build/path/plugin_name-plugin/tmp")
        FileUtils.should_receive(:mkdir_p).with("build/path/plugin_name-plugin/tmp")

        @plugin.should_receive(:execute).with('a', 3)

        FileUtils.should_receive(:mv).with("build/path/plugin_name-plugin/tmp/disk", "build/path/plugin_name-plugin/disk")
        FileUtils.should_receive(:rm_rf).with("build/path/plugin_name-plugin/tmp")

        @plugin.run('a', 3)
      end

      it "should fail if OS is not supported" do
        @plugin.register_supported_os('fedora', ['12', '13'])
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '14'}))
        @log.should_receive(:error).with('Amazon Simple Storage Service (Amazon S3) plugin supports following operating systems: fedora (versions: 12, 13). Your appliance contains fedora 14 operating system which is not supported by this plugin, sorry.')
        @plugin.run
      end
    end

    it "should register a supported os" do
      @plugin.register_supported_os('fedora', ['12', '13'])

      oses = @plugin.instance_variable_get(:@supported_oses)

      oses.size.should == 1
      oses['fedora'].size.should == 2
      oses['fedora'].should == ['12', '13']
    end

    it "should return that the OS is supported" do
      @plugin.register_supported_os('fedora', ['12', '13'])

      @plugin.instance_variable_get(:@appliance_config).os.name = 'fedora'
      @plugin.instance_variable_get(:@appliance_config).os.version = '12'

      @plugin.is_supported_os?.should == true
    end

    it "should return that the OS is not supported" do
      @plugin.register_supported_os('fedora', ['1223'])

      @plugin.instance_variable_get(:@appliance_config).os.name = 'fedora'
      @plugin.instance_variable_get(:@appliance_config).os.version = '12'

      @plugin.is_supported_os?.should == false
    end

    it "should return false when no operating systems are specified" do
      @plugin.is_supported_os?.should == true
    end

    it "should return supported os string" do
      @plugin.register_supported_os('fedora', ['12', '13'])
      @plugin.register_supported_os('centos', ['5'])

      @plugin.supported_oses.should == "centos (versions: 5), fedora (versions: 12, 13)"
    end

    it "should set default config value" do
      @plugin.set_default_config_value('key', 'avalue')

      @plugin.instance_variable_get(:@plugin_config)['key'].should == 'avalue'
    end

    it "should read plugin config" do
      @plugin.instance_variable_set(:@config_file, "configfile")

      File.should_receive(:exists?).with('configfile').and_return(true)
      YAML.should_receive(:load_file).with('configfile').and_return('abcdef')

      @plugin.read_plugin_config

      @plugin.instance_variable_get(:@plugin_config).should == 'abcdef'
    end

    it "should read plugin config and log warning an exception" do
      log = mock("Log")

      log.should_receive(:debug).with("Reading configuration file for BoxGrinder::BasePlugin.")
      log.should_receive(:warn).with("An error occurred while reading configuration file 'configfile' for BoxGrinder::BasePlugin. Is it a valid YAML file?")

      @plugin.instance_variable_set(:@log, log)
      @plugin.instance_variable_set(:@config_file, "configfile")

      File.should_receive(:exists?).with('configfile').and_return(true)
      YAML.should_receive(:load_file).with('configfile').and_raise('something')

      @plugin.read_plugin_config
    end

    describe ".current_platform" do
      it "should return raw" do
        @plugin.current_platform.should == 'raw'
      end

      it "should return vmware" do
        @plugin.instance_variable_set(:@previous_plugin_info, {:type => :platform, :name => :vmware})

        @plugin.current_platform.should == 'vmware'
      end
    end

    describe ".validate_plugin_config" do
      it "should validate plugn config" do
        @plugin.instance_variable_set(:@plugin_config, {'one' => :platform, 'two' => :vmware})

        @plugin.validate_plugin_config(['one', 'two'])
      end

      it "should raise because some data isn't provided" do
        @plugin.instance_variable_set(:@plugin_config, {'one' => :platform, 'two' => :vmware})

        lambda {
          @plugin.validate_plugin_config(['one', 'two', 'three'])
        }.should raise_error(RuntimeError, /^Please specify a valid 'three' key in plugin configuration file:/)
      end
    end

    it "should not allow to execute the plugin before initialization" do
      @plugin = BasePlugin.new

      lambda {
        @plugin.execute
      }.should raise_error(RuntimeError, "You can only execute the plugin after the plugin is initialized, please initialize the plugin using init method.")
    end

    it "should return target deliverables" do
      @plugin.register_deliverable(:disk => "disk", :vmx => "vmx")
      @plugin.deliverables.should == {:disk => "build/path/plugin_name-plugin/disk", :vmx => "build/path/plugin_name-plugin/vmx"}
    end
  end
end
