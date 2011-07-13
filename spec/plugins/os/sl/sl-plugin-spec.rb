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

require 'boxgrinder-build/plugins/os/sl/sl-plugin'
require 'rspec'
require 'hashery/opencascade'

module BoxGrinder
  describe ScientificLinuxPlugin do
    before(:each) do
      @config = Config.new
      @appliance_config = mock(ApplianceConfig,
        :name => 'name',
        :path => OpenCascade.new({:build => 'build/path'})
      )

      @plugin = ScientificLinuxPlugin.new.init(@config, @appliance_config, {:class => BoxGrinder::ScientificLinuxPlugin, :type => :os, :name => :sl, :full_name  => "Scientific Linux", :versions   => ["5", "6"]}, :log => LogHelper.new(:level => :trace, :type => :stdout))

    end

    describe ".execute" do
      it "should use rhel plugin to build the appliance" do
        @plugin.should_receive(:build_rhel).with('definition', {"6"=>{"security"=>{"baseurl"=>"http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/updates/security/"}, "base"=>{"baseurl"=>"http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/os/"}}, "5"=>{"security"=>{"baseurl"=>"http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/updates/security/"}, "base"=>{"baseurl"=>"http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/SL/"}}})

        @plugin.execute('definition')
      end
    end
  end
end
 
