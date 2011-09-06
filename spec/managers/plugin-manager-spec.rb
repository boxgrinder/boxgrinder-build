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
require 'boxgrinder-build/managers/plugin-manager'

module BoxGrinder
  describe PluginManager do

    before(:each) do
      @manager = PluginManager.instance
    end

    it "should register simple plugin" do
      @manager.register_plugin({:class => PluginManager, :type => :delivery, :name => :abc, :full_name => "Amazon Simple Storage Service (Amazon S3)"})

      @manager.plugins[:delivery].size.should == 9
      @manager.plugins[:delivery][:abc][:class].should == PluginManager
    end

    it "should register plugin with many types" do
      @manager.register_plugin({:class => PluginManager, :type => :delivery, :name => :def, :full_name => "Amazon Simple Storage Service (Amazon S3)", :types => [:aaa, :bbb, :ccc]})

      @manager.plugins[:delivery].size.should == 12
      @manager.plugins[:delivery][:abc][:class].should == PluginManager
      @manager.plugins[:delivery][:aaa][:class].should == PluginManager
      @manager.plugins[:delivery][:bbb][:class].should == PluginManager
      @manager.plugins[:delivery][:ccc][:class].should == PluginManager
    end

    it "should initialize a plugin" do
      plugin = mock('Plugin')

      clazz = mock('Class')
      clazz.should_receive(:new).and_return(plugin)

      @manager.instance_variable_set(:@plugins, {:delivery => {}, :os => {:fedora => {:class => clazz}}, :platform => {}})
      @manager.initialize_plugin(:os, :fedora).should == [plugin, {:class => clazz}]
    end

    it "should raise if plugin initialization cannot be finished" do
      clazz = mock('Class')
      clazz.should_receive(:new).and_raise("Something")
      clazz.should_receive(:to_s).and_return("Fedora")

      @manager.instance_variable_set(:@plugins, {:delivery => {}, :os => {:fedora => {:class => clazz}}, :platform => {}})

      lambda {
        @manager.initialize_plugin(:os, :fedora)
      }.should raise_error("Error while initializing 'Fedora' plugin.")
    end

    it "should register the plugin with 'plugin' method" do
      plugin_manager = mock(PluginManager)
      plugin_manager.should_receive(:register_plugin).with(:class => String, :type => :platform, :name => :ec2, :full_name  => "Amazon Elastic Compute Cloud (Amazon EC2)")

      PluginManager.should_receive(:instance).and_return(plugin_manager)

      plugin :class => String, :type => :platform, :name => :ec2, :full_name  => "Amazon Elastic Compute Cloud (Amazon EC2)"
    end
  end
end
