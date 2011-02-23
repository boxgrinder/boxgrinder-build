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

require 'boxgrinder-core/helpers/log-helper'
require 'boxgrinder-build/helpers/plugin-helper'
require 'ostruct'

module BoxGrinder
  describe PluginHelper do
    before(:each) do
      @log = LogHelper.new(:level => :trace, :type => :stdout)
      @plugin_helper = PluginHelper.new(OpenStruct.new(:additional_plugins => []), :log => @log)
    end

    it "should read plugins specified in command line" do
      @plugin_helper = PluginHelper.new(OpenStruct.new(:additional_plugins => ['abc', 'def']), :log => @log)

      @plugin_helper.should_receive(:require).ordered.with('abc')
      @plugin_helper.should_receive(:require).ordered.with('def')

      @plugin_helper.read_and_require
    end

    it "should read plugins specified in command line and warn if plugin cannot be loaded" do
      @log = mock('Logger')
      @plugin_helper = PluginHelper.new(OpenStruct.new(:additional_plugins => ['abc']), :log => @log)

      @log.should_receive(:trace).with("Loading plugin 'abc'...")
      @plugin_helper.should_receive(:require).ordered.with('abc').and_raise(LoadError)
      @log.should_receive(:trace).with("- Not found: LoadError")
      @log.should_receive(:warn).with("Specified plugin: 'abc' wasn't found. Make sure its name is correct, skipping...")

      @plugin_helper.read_and_require
    end

    it "should print os plugins" do
      @log = mock('Logger')

      @plugin_helper.instance_variable_set(:@log, @log)

      @log.should_receive(:debug).with('Loading os plugins...')
      @log.should_receive(:debug).with('We have 1 os plugin(s) registered')
      @log.should_receive(:debug).with("- fedora plugin for Fedora.")
      @log.should_receive(:debug).with('Plugins loaded.')

      @plugin_helper.print_plugins('os') { {'fedora' => {:full_name => "Fedora"}} }
    end

    it "should load all plugins" do
      @plugin_helper.should_receive(:read_and_require)

      plugin_manager = mock('PluginManager')
      plugin_manager.stub!(:plugins).and_return({:os =>{}, :platform =>{}, :delivery =>{}})

      PluginManager.stub!(:instance).and_return(plugin_manager)

      @plugin_helper.should_receive(:print_plugins).with('os')
      @plugin_helper.should_receive(:print_plugins).with('platform')
      @plugin_helper.should_receive(:print_plugins).with('delivery')

      @plugin_helper.load_plugins
    end
  end
end

