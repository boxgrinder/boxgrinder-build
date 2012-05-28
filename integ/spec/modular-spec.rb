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
require 'boxgrinder-build'
require 'boxgrinder-build/appliance'
require 'boxgrinder-build/helpers/guestfs-helper'
require 'boxgrinder-core'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/log-helper'
require 'fileutils'

module BoxGrinder
  describe 'BoxGrinder Build' do
    before(:all) do
      # Cleaning up before build
      FileUtils.rm_rf('build/')

      # Prepare local repository
      FileUtils.mkdir_p "/tmp/boxgrinder-repo/"
      FileUtils.cp "#{File.dirname(__FILE__)}/../packages/ephemeral-repo-test-0.1-1.noarch.rpm", "/tmp/boxgrinder-repo/"
      system "createrepo /tmp/boxgrinder-repo/"
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
    end

    context "modular appliances" do
      it "should build modular appliance based on Fedora and convert it to VirtualBox" do
        @config.merge!(:platform => :virtualbox)
        @appliance = Appliance.new("#{File.dirname(__FILE__)}/../appliances/modular/modular.appl", @config, :log => @log).create

        GuestFSHelper.new([@appliance.plugin_chain[1][:plugin].deliverables[:disk]], @appliance.appliance_config, @config, :log => @log ).customize do |guestfs, guestfs_helper|
          guestfs.exists('/fedora-boxgrinder-test').should == 1
          guestfs.exists('/common-test-base-boxgrinder-test').should == 1
          guestfs.exists('/hardware-cpus-boxgrinder-test').should == 1
          guestfs.exists('/repos-boxgrinder-noarch-ephemeral-boxgrinder-test').should == 1
        end
      end
    end
  end
end

