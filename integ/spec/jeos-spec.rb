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
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/log-helper'

module BoxGrinder
  describe 'BoxGrinder Build' do
    before(:each) do
      # By default remove all previous builds and deliver the packaged appliance to S3
      @config = Config.new(:force => true, :delivery => :s3)
      @log = LogHelper.new(:level => :trace, :type => :stdout)
    end

    after(:each) do
      # Execute the build!
      @appliance = Appliance.new("#{File.dirname(__FILE__)}/../appliances/#{@definition}", @config, :log => @log).create

      # Make sure all deliverables really exists
      @appliance.plugin_chain.last[:plugin].deliverables.each_value do |file|
        File.exists?(file).should == true
      end
    end

    context "operating system plugin" do
      it "should build Fedora 15 JEOS" do
        @definition = "jeos-f15.appl"
      end

      it "should build CentOS 5 JEOS" do
        @definition = "jeos-centos5.appl"
      end
    end

    context "platform plugin" do
      it "should create Fedora 15 JEOS appliance and convert it to VMware personal platform" do
        @config.merge!(:platform => :vmware, :platform_config => {'type' => 'personal'})
        @definition = "jeos-f15.appl"
      end
    end
  end
end

