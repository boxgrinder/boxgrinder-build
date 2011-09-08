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
require 'boxgrinder-build/helpers/guestfs-helper'
require 'fileutils'

module BoxGrinder
  describe 'BoxGrinder Build' do
    before(:all) do
      # Cleaning up before build
      FileUtils.rm_rf('build/')
    end

    after(:all) do
      # Cleaning up after build
      FileUtils.rm_rf('build/')
    end

    before(:each) do
      # Deliver the packaged appliance to CloudFront
      @config = Config.new(:delivery => :cloudfront)
      @log = LogHelper.new(:level => :trace, :type => :stdout)
    end

    after(:each) do
      # Make sure all deliverables really exists
      @appliance.plugin_chain.last[:plugin].deliverables.each_value do |file|
        File.exists?(file).should == true
      end
        
      GuestFSHelper.new([@appliance.plugin_chain.first[:plugin].deliverables[:disk]], @appliance.appliance_config, @config, :log => @log ).customize do |guestfs, guestfs_helper| 
        guestfs.exists('/opt/jeos-f16-files.appl').should == 1
        guestfs.exists('/opt/etc/yum.repos.d/fedora.repo').should == 1
        guestfs.exists('/opt/etc/sysconfig/network').should == 1
        guestfs.exists('/opt/abc/apache-couchdb-1.0.3.tar.gz').should == 1
        guestfs.exists('/opt/abc/README.md').should == 1
        guestfs.exists('/opt/abc/apache-couchdb-1.1.0.tar.gz').should == 1
      end
    end

    context "Files section" do
      it "should build appliance with files section for Fedora 16" do
        @appliance = Appliance.new("#{File.dirname(__FILE__)}/../appliances/jeos-f16-files.appl", @config, :log => @log).create
      end
        
      it "should build appliance with files section for CentOS 5" do
        @appliance = Appliance.new("#{File.dirname(__FILE__)}/../appliances/jeos-centos5-files.appl", @config, :log => @log).create
      end
    end
  end
end

