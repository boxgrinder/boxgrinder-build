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

require 'boxgrinder-build/helpers/appliance-customize-helper'

module BoxGrinder
  describe ApplianceCustomizeHelper do

    before(:each) do
      @config = mock('Config')
      @config.stub!(:name).and_return('BoxGrinder')
      @config.stub!(:version_with_release).and_return('0.1.2')

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:summary).and_return('asd')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '11'}))
      @appliance_config.stub!(:post).and_return(OpenCascade.new({:vmware => []}))

      @appliance_config.stub!(:hardware).and_return(
          OpenCascade.new({
                           :partitions =>
                               {
                                   '/' => {'size' => 2},
                                   '/home' => {'size' => 3},
                               },
                           :arch => 'i686',
                           :base_arch => 'i386',
                           :cpus => 1,
                           :memory => 256,
                       })
      )

      @helper = ApplianceCustomizeHelper.new(@config, @appliance_config, 'a/disk', :log => Logger.new('/dev/null'))

      @log = @helper.instance_variable_get(:@log)
    end

    it "should properly prepare guestfs for customization" do

      guestfs_helper = mock('guestfs_helper')
      guestfs = mock('guestfs')
      guestfs_helper.should_receive(:run).and_return(guestfs_helper)
      guestfs_helper.should_receive(:guestfs).and_return(guestfs)
      guestfs_helper.should_receive(:clean_close)

      GuestFSHelper.should_receive(:new).with('a/disk', :log =>  @log).and_return(guestfs_helper)

      @helper.customize do |gf, gf_helper|
        gf_helper.should == guestfs_helper
        gf.should == guestfs
      end
    end
  end
end
