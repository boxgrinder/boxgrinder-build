require 'boxgrinder-build/helpers/augeas-helper'

module BoxGrinder
  describe AugeasHelper do

    before(:each) do
      @log    = Logger.new('/dev/null')

      @guestfs = mock('GuestFS')
      @guestfs_helper = mock('GuestFSHelper')

      @helper = AugeasHelper.new( @guestfs, @guestfs_helper, :log => @log)
    end

    it "should not execute augeas commands if there a no files to change" do
      @helper.edit do
      end
    end

    it "should change configuration for one file" do
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set( '/etc/ssh/sshd_config', 'UseDNS', 'no')
      end
    end

    it "should change configuration for two files" do
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(1)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config' and . != '/etc/sysconfig/selinux']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_set).with("/files/etc/sysconfig/selinux/SELINUX", "permissive")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set( '/etc/ssh/sshd_config', 'UseDNS', 'no')
        set( '/etc/sysconfig/selinux', 'SELINUX', 'permissive')
      end
    end

    it "should change one configuration for two files because one file doesn't exists" do
      @guestfs.should_receive(:exists).with('/etc/ssh/sshd_config').and_return(1)
      @guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(0)
      @guestfs.should_receive(:aug_init).with('/', 32)
      @guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/ssh/sshd_config']")
      @guestfs.should_receive(:aug_load)
      @guestfs.should_receive(:aug_set).with("/files/etc/ssh/sshd_config/UseDNS", "no")
      @guestfs.should_receive(:aug_save)

      @helper.edit do
        set( '/etc/ssh/sshd_config', 'UseDNS', 'no')
        set( '/etc/sysconfig/selinux', 'SELINUX', 'permissive')
      end
    end
  end
end
