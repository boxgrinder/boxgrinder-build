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

require 'boxgrinder-build/plugins/os/centos/centos-plugin'
require 'hashery/opencascade'

module BoxGrinder
  describe CentOSPlugin do
    before(:each) do
      @config = mock('Config')
      @config.stub!(:os_config).and_return({})
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('centos').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')

      @plugin = CentOSPlugin.new.init(@config, @appliance_config, {:class => BoxGrinder::CentOSPlugin, :type => :os, :name => :centos, :full_name => "CentOS", :versions => ["5"]}, :log => Logger.new('/dev/null'))
    end

    it "should use basearch instead of arch in repository URLs" do
      @plugin.should_receive(:build_rhel).with('file', {
          "5" => {
              "updates" => {
                  "mirrorlist"=>"http://mirrorlist.centos.org/?release=#OS_VERSION#&arch=#BASE_ARCH#&repo=updates"},
              "base" => {
                  "mirrorlist"=>"http://mirrorlist.centos.org/?release=#OS_VERSION#&arch=#BASE_ARCH#&repo=os"}}
      })

      @plugin.execute('file')
    end
  end
end

