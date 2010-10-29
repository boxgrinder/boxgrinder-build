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
require 'rspec/rspec-config-helper'

module BoxGrinder
  describe ApplianceCustomizeHelper do
    include RSpecConfigHelper

    before(:each) do
      @helper = ApplianceCustomizeHelper.new(generate_config, generate_appliance_config, 'a/disk', :log => Logger.new('/dev/null'))

      @log = @helper.instance_variable_get(:@log)
    end

    it "should properly prepare guestfs for customization" do

      guestfs_helper = mock('guestfs_helper')
      guestfs = mock('guestfs')
      guestfs_helper.should_receive(:run).and_return(guestfs_helper)
      guestfs_helper.should_receive(:guestfs).and_return(guestfs)
      guestfs_helper.should_receive(:clean_close)

      GuestFSHelper.should_receive(:new).with('a/disk', :log =>  @log ).and_return(guestfs_helper)

      @helper.customize do |gf, gf_helper|
        gf_helper.should  == guestfs_helper
        gf.should         == guestfs
      end
    end
  end
end
