#
# Copyright 2012 Red Hat, Inc.
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

require 'boxgrinder-build/util/permissions/user-switcher'

module BoxGrinder          
  describe UserSwitcher do
    context "#change_user" do

      before(:each) do
        FileUtils.stub(:rm_rf)
      end
      
      it "should change from the current user to specified, then revert after the block" do
        Process.stub(:uid).and_return(1, 1, 2)
        Process.stub(:gid).and_return(3, 3, 4)
       
        # First switch
        Process.should_receive(:uid=).with(2)
        Process.should_receive(:euid=).with(2)
        Process.should_receive(:gid=).with(4)
        Process.should_receive(:egid=).with(4)


        # Change back
        Process.should_receive(:uid=).with(1)
        Process.should_receive(:euid=).with(1)
        Process.should_receive(:gid=).with(3)
        Process.should_receive(:egid=).with(3)
        
        UserSwitcher.change_user(2, 4){}
      end

      it "should not change user if the uid and gid already match" do 
        Process.stub(:uid).and_return(1)
        Process.stub(:gid).and_return(2)
        
        Process.should_not_receive(:uid=)
        Process.should_not_receive(:euid=)
        Process.should_not_receive(:gid=)
        Process.should_not_receive(:egid=)

        UserSwitcher.change_user(1, 2){}
      end
    end

    def stub_process_ids(u, g, eu=u, eg=g)
      Process.stub(:uid => u)
      Process.stub(:gid => g)
      Process.stub(:euid => eu)
      Process.stub(:egid => eg)
    end
  end
end
