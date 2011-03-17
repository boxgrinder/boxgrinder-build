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
require 'boxgrinder-build/plugins/os/fedora/fedora-plugin'
require 'hashery/opencascade'

module BoxGrinder
  describe FedoraPlugin do
    before(:each) do
      @config = mock('Config')
      @config.stub!(:os_config).and_return({})
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('fedora').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '13'}))
      @appliance_config.stub!(:hardware).and_return(OpenCascade.new({:arch => 'x86_64'}))
      @appliance_config.stub!(:is64bit?).and_return(true)

      @plugin = FedoraPlugin.new.init(@config, @appliance_config, :log => Logger.new('/dev/null'), :plugin_info => {:class => BoxGrinder::FedoraPlugin, :type => :os, :name => :fedora, :full_name => "Fedora", :versions => ["11", "12", "13", "14", "rawhide"]})

      @config = @plugin.instance_variable_get(:@config)
      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)
    end

    it "should normalize packages for 32bit" do
      packages = ['abc', 'def', 'kernel']

      @appliance_config.should_receive(:is64bit?).and_return(false)

      @plugin.normalize_packages(packages)
      packages.should == ["abc", "def", "@core", "system-config-firewall-base", "dhclient", "kernel-PAE"]
    end

    it "should normalize packages for 64bit" do
      packages = ['abc', 'def', 'kernel']

      @plugin.normalize_packages(packages)
      packages.should == ["abc", "def", "@core", "system-config-firewall-base", "dhclient", "kernel"]
    end

    it "should add packages for fedora 13" do
      packages = []

      @plugin.normalize_packages(packages)
      packages.should == ["@core", "system-config-firewall-base", "dhclient", "kernel"]
    end
  end
end

