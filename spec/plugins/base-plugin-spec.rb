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

require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-core/helpers/log-helper'
require 'yaml'

module BoxGrinder
  describe BasePlugin do
    before(:each) do
      @config = mock('Config')
      @config.stub!(:name).and_return('BoxGrinder')
      @config.stub!(:version_with_release).and_return('0.1.2')

      plugins = mock('Plugins')
      plugins.stub!(:[]).with('plugin_name').and_return({})

      @config.stub!(:[]).with(:plugins).and_return(plugins)
      @config.stub!(:file).and_return('/home/abc/boxgrinder_config_file')

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(AStruct.new({:build => 'build/path'}))
      @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'fedora', :version => '13'}))

      @log = LogHelper.new(:level => :trace, :type => :stdout)

      @plugin = BasePlugin.new
      @plugin.should_receive(:merge_plugin_config)
      @plugin.init(@config, @appliance_config, {:name => :plugin_name, :full_name => "Amazon Simple Storage Service (Amazon S3)"}, :log => @log)
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

    describe ".deliverables_exists?" do
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

        @plugin.deliverables_exists?.should == false
      end

      it "should return false if no deliverables are registerd" do
        @plugin.deliverables_exists?.should == false
      end
    end

    describe ".run" do
      it "should run the plugin" do
        @plugin.register_supported_os('fedora', ['12', '13'])
        @plugin.register_deliverable(:disk => "disk")

        FileUtils.should_receive(:rm_rf).with("build/path/plugin_name-plugin/tmp")
        FileUtils.should_receive(:mkdir_p).with("build/path/plugin_name-plugin/tmp")

        @plugin.should_receive(:execute)

        FileUtils.should_receive(:mv).with("build/path/plugin_name-plugin/tmp/disk", "build/path/plugin_name-plugin/disk")
        FileUtils.should_receive(:rm_rf).with("build/path/plugin_name-plugin/tmp")

        @plugin.run
      end

      it "should fail if OS is not supported" do
        @plugin.register_supported_os('fedora', ['12', '13'])
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'fedora', :version => '14'}))
        lambda { @plugin.run }.should raise_error(PluginValidationError, 'Amazon Simple Storage Service (Amazon S3) plugin supports following operating systems: fedora (versions: 12, 13). Your appliance contains fedora 14 operating system which is not supported by this plugin, sorry.')
      end

      it "should fail if platform is not supported" do
        @plugin.instance_variable_set(:@previous_plugin_info, {:type => :platform, :name => :ec2})
        @plugin.register_supported_platform('vmware')
        lambda {  @plugin.run }.should raise_error(PluginValidationError, 'Amazon Simple Storage Service (Amazon S3) plugin supports following platforms: vmware. You selected ec2 platform which is not supported by this plugin, sorry.')
      end

      it "should not fail if previous plugin is not a platform plugin" do
        @plugin.instance_variable_set(:@previous_plugin_info, {:type => :os, :name => :fedora})
        @plugin.register_supported_platform('vmware')
        @log.should_not_receive(:error)
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

    it "should not be overwritten by default value assignment"
      @plugin.instance_variable_set(:@plugin_config, {'key' => false})
      @plugin.set_default_config_value('key', true)

      @plugin.instance_variable_get(:@plugin_config)['key'].should == false
    end

    describe ".read_plugin_config" do
      it "should read plugin config" do
        plugins = mock('Plugins')
        plugins.stub!(:[]).with('plugin_name').and_return({'abc' => 'def'})
        @config.stub!(:[]).with(:plugins).and_return(plugins)

        @plugin.read_plugin_config
        @plugin.instance_variable_get(:@plugin_config)['abc'].should == 'def'
      end

      it "should read plugin config and exit early" do
        @config.stub!(:[]).with(:plugins).and_return(nil)
        @plugin.read_plugin_config
      end
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
        }.should raise_error(PluginValidationError, "Please specify a valid 'three' key in BoxGrinder configuration file: '/home/abc/boxgrinder_config_file' or use CLI '---config three:DATA' argument. ")
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
