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

require 'boxgrinder-build/helpers/augeas-helper'

module BoxGrinder
  describe AugeasHelper do

    before(:each) do
      @log    = Logger.new('/dev/null')

      @guestfs = mock('GuestFS')
      @guestfs_helper = mock('GuestFSHelper')

      @helper = AugeasHelper.new(@guestfs, @guestfs_helper, :log => @log)
    end

    it "should not execute augeas commands if there a no files to change" do
      @helper.edit do
      end
    end

    it "should change configuration for one file" do
      @guestfs.should_receive(:debug).with("help", []).and_return("core_pattern")
      @guestfs.should_receive(:debug).with("core_pattern", ["/sysroot/core"])
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set('/etc/ssh/sshd_config', 'UseDNS', 'no')
      end
    end

    it "should change configuration for two files" do
      @guestfs.should_receive(:debug).with("help", []).and_return("core_pattern")
      @guestfs.should_receive(:debug).with("core_pattern", ["/sysroot/core"])
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(1)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config' and . != '/etc/sysconfig/selinux']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_set).with("/files/etc/sysconfig/selinux/SELINUX", "permissive")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set('/etc/ssh/sshd_config', 'UseDNS', 'no')
        set('/etc/sysconfig/selinux', 'SELINUX', 'permissive')
      end
    end

    it "should change one configuration for two files because one file doesn't exists" do
      @guestfs.should_receive(:debug).with("help", []).and_return("core_pattern")
      @guestfs.should_receive(:debug).with("core_pattern", ["/sysroot/core"])
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(0)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set('/etc/ssh/sshd_config', 'UseDNS', 'no')
        set('/etc/sysconfig/selinux', 'SELINUX', 'permissive')
      end
    end

    it "should not set core_patter debug method because it's not supported" do
      @guestfs.should_receive(:debug).with("help", []).and_return("something")
      @guestfs.should_not_receive(:debug).with("core_pattern", ["/sysroot/core"])
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set('/etc/ssh/sshd_config', 'UseDNS', 'no')
      end
    end
  end
end
