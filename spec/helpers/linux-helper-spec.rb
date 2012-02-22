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

require 'boxgrinder-build/helpers/linux-helper'

module BoxGrinder
  describe LinuxHelper do

    before(:each) do
      @helper = LinuxHelper.new(:log => Logger.new('/dev/null'))

      @log = @helper.instance_variable_get(:@log)
    end

    it "should not fail when no versions are found" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return([])
      @helper.kernel_version(guestfs).should == nil
    end

    it "should return valid kernel version" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return(['2.6.33.6-147.fc13.i686'])
      @helper.kernel_version(guestfs).should == '2.6.33.6-147.fc13.i686'
    end

    it "should return valid PAE kernel version" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return(['2.6.33.6-147.fc13.i686.PAE', '2.6.33.6-147.fc13.i686'])
      @helper.kernel_version(guestfs).should == '2.6.33.6-147.fc13.i686.PAE'
    end

    it "should return valid xen kernel version" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return(['2.6.33.6-147.fc13.i686.xen', '2.6.40.6-147.fc13.i686'])
      @helper.kernel_version(guestfs).should == '2.6.33.6-147.fc13.i686.xen'
    end

    it "should return valid xen kernel version" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:ls).with('/lib/modules').and_return(['2.6.45.6-147.fc13.i686', '2.6.40.6-147.fc13.i686'])
      @helper.kernel_version(guestfs).should == '2.6.45.6-147.fc13.i686'
    end

    it "should fail when no kernel images could be found" do
      @helper.should_receive(:kernel_version).and_return(nil)

      lambda { @helper.recreate_kernel_image("guestfs", ['xennet']) }.should raise_error("Cannot find valid kernel installs in the appliance. Make sure you have your kernel installed in '/lib/modules'.")
    end

    it "should recreate initramfs kernel image using dracut and add xennet module" do
      guestfs = mock("guestfs")

      @helper.should_receive(:kernel_version).and_return('2.6.33.6-147.fc13.i686.PAE')
      guestfs.should_receive(:sh).with('ls -1 /boot | grep initramfs | wc -l').and_return("1 ")

      guestfs.should_receive(:exists).with('/sbin/dracut').and_return(1)
      guestfs.should_receive(:sh).with("/sbin/dracut -f -v --add-drivers xennet /boot/initramfs-2.6.33.6-147.fc13.i686.PAE.img 2.6.33.6-147.fc13.i686.PAE")

      @helper.recreate_kernel_image(guestfs, ['xennet'])
    end

    it "should recreate initrd kernel image using mkinitrd and add xenblk and xennet module" do
      guestfs = mock("guestfs")

      @helper.should_receive(:kernel_version).and_return('2.6.33.6-147.fc13.i686.PAE')
      guestfs.should_receive(:sh).with('ls -1 /boot | grep initramfs | wc -l').and_return(" 0 ")

      guestfs.should_receive(:exists).with('/sbin/dracut').and_return(0)
      guestfs.should_receive(:sh).with("/sbin/mkinitrd -f -v --preload=xenblk --preload=xennet /boot/initrd-2.6.33.6-147.fc13.i686.PAE.img 2.6.33.6-147.fc13.i686.PAE")

      @helper.recreate_kernel_image(guestfs, ['xenblk', 'xennet'])
    end

    describe ".partition_mount_points" do
      it "should return ['/', '/home']" do
        hash = {"/"=>{"size"=>2, "type"=>"ext3"}, "/home"=>{"size"=>2, "type"=>"ext3"}}
        @helper.partition_mount_points(hash).should == ['/', '/home']
      end

      it "should return ['/', '/home', 'swap']" do
        hash = {'swap' => {"size" => 1}, "/"=>{"size"=>2, "type"=>"ext3"}, "/home"=>{"size"=>2, "type"=>"ext3"}}
        @helper.partition_mount_points(hash).should == ['/', '/home', 'swap']
      end

      it "should return ['/', '/boot', '/home', 'swap']" do
        hash = {'swap' => {"size" => 1}, "/boot" => {"size" => 0.1}, "/"=>{"size"=>2, "type"=>"ext3"}, "/home"=>{"size"=>2, "type"=>"ext3"}}
        @helper.partition_mount_points(hash).should == ['/', '/boot', '/home', 'swap']
      end

      it "should return ['/', '/ubrc', '/tmp-config', '/tmp-eventlog']" do
        hash = {"/tmp-eventlog"=>{"size"=>0.01, "type"=>"ext3"}, "/"=>{"size"=>2, "type"=>"ext3"}, "/ubrc"=>{"size"=>0.02, "type"=>"ext3"}, "/tmp-config"=>{"size"=>0.26}}
        @helper.partition_mount_points(hash).should == ["/", "/ubrc", "/tmp-config", "/tmp-eventlog"]
      end

      it "should return ['/', '/tmp-config', '/tmp-eventlog', '/var/www']" do
        hash = {"/tmp-eventlog"=>{}, "/"=>{}, "/var/www"=>{}, "/tmp-config"=>{}}
        @helper.partition_mount_points(hash).should == ['/', '/tmp-config', '/tmp-eventlog', '/var/www']
      end
    end

    context "RPMVersion" do
      before(:each) do
        @version = RPMVersion.new
      end

      it "should split the version" do
        @version.split('2.6.18-274.7.1.el5').should == ["2", "6", "18", "274", "7", "1", "el5"]
      end

      describe ".compare" do
        it "should compare two versions and return -1" do
          @version.compare("2.6.18-274.7.1.el5", "2.6.18-8.el5").should == 1
        end

        it "should compare two versions and return 1" do
          @version.compare("2.6.18-8.el5", "2.6.18-274.7.1.el5").should == -1
        end

        it "should compare two versions and return 0" do
          @version.compare("2.6.18-8.el5", "2.6.18-8.el5").should == 0
        end

        it "should compare two very similar versions" do
          @version.compare("2.6.18-8.el5", "2.6.18-8.1.el5").should == -1
        end

        it "should compare two very similar versions other way around" do
          @version.compare("2.6.18-8.1.el5", "2.6.18-8.el5").should == 1
        end
      end

      describe ".newest" do
        it "should return first one as newer" do
          @version.newest(["2.6.18-274.7.1.el5", "2.6.18-8.el5"]).should == "2.6.18-274.7.1.el5"
        end

        it "should return last one as newer" do
          @version.newest(["2.6.18-8.el5", "2.6.18-274.7.1.el5"]).should == "2.6.18-274.7.1.el5"
        end

        it "should return version 3 as newer" do
          @version.newest(["3.1.0-0.rc1", "2.6.18-274.7.1.el5"]).should == "3.1.0-0.rc1"
        end
      end
    end
  end
end

