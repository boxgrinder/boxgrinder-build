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
require 'boxgrinder-build/helpers/linux-helper'

module BoxGrinder
  describe LinuxHelper do

    before(:each) do
      @helper = LinuxHelper.new( :log => Logger.new('/dev/null') )

      @log = @helper.instance_variable_get(:@log)
    end

    it "should return valid kernel version" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return(['2.6.33.6-147.fc13.i686'])
      @helper.kernel_version( guestfs ).should == '2.6.33.6-147.fc13.i686'
    end

    it "should return valid PAE kernel version" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return(['2.6.33.6-147.fc13.i686.PAE', '2.6.33.6-147.fc13.i686'])
      @helper.kernel_version( guestfs ).should == '2.6.33.6-147.fc13.i686.PAE'
    end

    it "should recreate initramfs kernel image using dracut and add xennet module" do
      guestfs = mock("guestfs")

      @helper.should_receive(:kernel_version).and_return('2.6.33.6-147.fc13.i686.PAE')
      guestfs.should_receive(:sh).with('ls -1 /boot | grep initramfs | wc -l').and_return("1 ")

      guestfs.should_receive(:exists).with('/sbin/dracut').and_return(1)
      guestfs.should_receive(:sh).with("/sbin/dracut -f -v --add-drivers xennet /boot/initramfs-2.6.33.6-147.fc13.i686.PAE.img 2.6.33.6-147.fc13.i686.PAE")

      @helper.recreate_kernel_image( guestfs, ['xennet'] )
    end

    it "should recreate initrd kernel image using mkinitrd and add xenblk and xennet module" do
      guestfs = mock("guestfs")

      @helper.should_receive(:kernel_version).and_return('2.6.33.6-147.fc13.i686.PAE')
      guestfs.should_receive(:sh).with('ls -1 /boot | grep initramfs | wc -l').and_return(" 0 ")

      guestfs.should_receive(:exists).with('/sbin/dracut').and_return(0)
      guestfs.should_receive(:sh).with("/sbin/mkinitrd -f -v --preload=xenblk --preload=xennet /boot/initrd-2.6.33.6-147.fc13.i686.PAE.img 2.6.33.6-147.fc13.i686.PAE")

      @helper.recreate_kernel_image( guestfs, ['xenblk', 'xennet'] )
    end

  end
end

