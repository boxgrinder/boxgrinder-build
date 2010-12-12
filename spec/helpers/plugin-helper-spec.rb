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

require 'boxgrinder-build/helpers/plugin-helper'
require 'ostruct'

module BoxGrinder
  describe PluginHelper do
    before(:all) do
      @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
      @plugin_array = %w(boxgrinder-build-fedora-os-plugin boxgrinder-build-rhel-os-plugin boxgrinder-build-centos-os-plugin boxgrinder-build-ec2-platform-plugin boxgrinder-build-vmware-platform-plugin boxgrinder-build-s3-delivery-plugin boxgrinder-build-sftp-delivery-plugin boxgrinder-build-local-delivery-plugin boxgrinder-build-ebs-delivery-plugin)
    end

    before(:each) do
      @plugin_helper = PluginHelper.new(:options => OpenStruct.new)
    end

    it "should parse plugin list and return empty array when no plugins are provided" do
      @plugin_helper.parse_plugin_list.should == []
    end

    it "should parse plugin list with double quotes" do
      @plugin_helper = PluginHelper.new(:options => OpenStruct.new(:plugins => '"abc,def"'))
      @plugin_helper.parse_plugin_list.should == ['abc', 'def']
    end

    it "should parse plugin list with single quotes" do
      @plugin_helper = PluginHelper.new(:options => OpenStruct.new(:plugins => "'abc,def'"))
      @plugin_helper.parse_plugin_list.should == ['abc', 'def']
    end

    it "should parse plugin list with single quotes and clean up it" do
      @plugin_helper = PluginHelper.new(:options => OpenStruct.new(:plugins => "'    abc ,    def'"))
      @plugin_helper.parse_plugin_list.should == ['abc', 'def']
    end

    it "should require default plugins" do
      @plugin_array.each do |plugin|
        @plugin_helper.should_receive(:require).once.with(plugin)
      end

      @plugin_helper.read_and_require
    end

    it "should read plugins specified in command line" do
      @plugin_helper = PluginHelper.new(:options => OpenStruct.new(:plugins => 'abc,def'))

      @plugin_array.each do |plugin|
        @plugin_helper.should_receive(:require).once.with(plugin)
      end

      @plugin_helper.should_receive(:require).ordered.with('abc')
      @plugin_helper.should_receive(:require).ordered.with('def')

      @plugin_helper.read_and_require
    end
  end
end

