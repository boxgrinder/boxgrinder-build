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

require 'boxgrinder-build/appliance'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/helpers/log-helper'

module BoxGrinder
  describe 'JEOS' do
    before(:each) do
      @config = Config.new
      @log = LogHelper.new(:level => :trace, :type => :stdout)
    end

    context "operating system" do
      it "should build Fedora 15 JEOS" do
        Appliance.new("#{File.dirname(__FILE__)}/../appliances/jeos-f15.appl", @config, :log => @log).create
      end

      it "should build CentOS 5 JEOS" do
        Appliance.new("#{File.dirname(__FILE__)}/../appliances/jeos-centos5.appl", @config, :log => @log).create
      end
    end
  end
end

