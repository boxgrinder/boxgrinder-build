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

