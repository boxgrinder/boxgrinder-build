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

require 'boxgrinder-build/plugins/os/rpm-based/rpm-based-os-plugin'
require 'hashery/opencascade'

module BoxGrinder
  describe RPMBasedOSPlugin do
    before(:each) do
      @config = mock('Config')
      @appliance_config = mock('ApplianceConfig')
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('rpm_based').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '11'}))

      @plugin = RPMBasedOSPlugin.new

      @plugin.stub!(:merge_plugin_config)

      @plugin.init(@config, @appliance_config, :log => Logger.new('/dev/null'), :plugin_info => {:name => :rpm_based})

      @config = @plugin.instance_variable_get(:@config)
      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)
    end

    it "should install repos" do
      @appliance_config.should_receive(:repos).and_return(
          [
              {'name' => 'cirras', 'baseurl' => "http://repo.boxgrinder.org/packages/fedora/11/RPMS/x86_64"},
              {'name' => 'abc', 'baseurl' => 'http://abc', 'mirrorlist' => "http://abc.org/packages/fedora/11/RPMS/x86_64"},
          ])

      guestfs = mock("guestfs")
      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/cirras.repo", "[cirras]\nname=cirras\nenabled=1\ngpgcheck=0\nbaseurl=http://repo.boxgrinder.org/packages/fedora/11/RPMS/x86_64\n", 0)
      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/abc.repo", "[abc]\nname=abc\nenabled=1\ngpgcheck=0\nbaseurl=http://abc\nmirrorlist=http://abc.org/packages/fedora/11/RPMS/x86_64\n", 0)

      @plugin.install_repos(guestfs)
    end

    it "should not install ephemeral repos" do
      @appliance_config.should_receive(:repos).and_return(
          [
              {'name' => 'abc', 'baseurl' => 'http://abc', 'mirrorlist' => "http://abc.org/packages/fedora/11/RPMS/x86_64"},
              {'name' => 'cirras', 'baseurl' => "http://repo.boxgrinder.org/packages/fedora/11/RPMS/x86_64", 'ephemeral' => true}
          ])

      guestfs = mock("guestfs")
      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/abc.repo", "[abc]\nname=abc\nenabled=1\ngpgcheck=0\nbaseurl=http://abc\nmirrorlist=http://abc.org/packages/fedora/11/RPMS/x86_64\n", 0)

      @plugin.install_repos(guestfs)
    end

    it "should read kickstart definition file" do
      @plugin.should_receive(:read_kickstart).with('file.ks')
      @plugin.read_file('file.ks')
    end

    it "should read other definition file" do
      @plugin.should_not_receive(:read_kickstart)
      @plugin.read_file('file.other')
    end

    describe ".read_kickstart" do
      it "should read and parse valid kickstart file with bg comments" do
        appliance_config = @plugin.read_kickstart("#{File.dirname(__FILE__)}/src/jeos-f13.ks")
        appliance_config.should be_an_instance_of(ApplianceConfig)
        appliance_config.os.name.should == 'fedora'
        appliance_config.os.version.should == '13'
      end

      it "should raise while parsing kickstart file *without* bg comments" do
        lambda {
          @plugin.read_kickstart("#{File.dirname(__FILE__)}/src/jeos-f13-plain.ks")
        }.should raise_error("No operating system name specified, please add comment to you kickstrt file like this: # bg_os_name: fedora")
      end

      it "should raise while parsing kickstart file *without* bg version comment" do
        lambda {
          @plugin.read_kickstart("#{File.dirname(__FILE__)}/src/jeos-f13-without-version.ks")
        }.should raise_error("No operating system version specified, please add comment to you kickstrt file like this: # bg_os_version: 14")
      end
    end

    it "should fix partition labels" do
      guestfs = mock("guestfs")

      guestfs.should_receive(:list_partitions).and_return(['/dev/vda1', '/dev/vda2'])
      guestfs.should_receive(:vfs_label).with('/dev/vda1').and_return('_/')
      guestfs.should_receive(:vfs_label).with('/dev/vda2').and_return('_/boot')

      guestfs.should_receive(:sh).with('/sbin/e2label /dev/vda1 /')
      guestfs.should_receive(:sh).with('/sbin/e2label /dev/vda2 /boot')

      @plugin.fix_partition_labels(guestfs)
    end

    describe ".use_labels_for_partitions" do
      it "should use labels for partitions instead of paths" do
        guestfs = mock("guestfs")

        guestfs.should_receive(:list_devices).and_return(['/dev/hda'])

        guestfs.should_receive(:read_file).with('/etc/fstab').and_return("/dev/sda1 / something\nLABEL=/boot /boot something\n")
        guestfs.should_receive(:vfs_label).with('/dev/hda1').and_return('/')
        guestfs.should_receive(:write_file).with('/etc/fstab', "LABEL=/ / something\nLABEL=/boot /boot something\n", 0)

        guestfs.should_receive(:read_file).with('/boot/grub/grub.conf').and_return("default=0\ntimeout=5\nsplashimage=(hd0,0)/boot/grub/splash.xpm.gz\nhiddenmenu\ntitle f14-core (2.6.35.10-74.fc14.x86_64)\nroot (hd0,0)\nkernel /boot/vmlinuz-2.6.35.10-74.fc14.x86_64 ro root=/dev/sda1\ninitrd /boot/initramfs-2.6.35.10-74.fc14.x86_64.img")
        guestfs.should_receive(:vfs_label).with('/dev/hda1').and_return('/')
        guestfs.should_receive(:write_file).with('/boot/grub/grub.conf', "default=0\ntimeout=5\nsplashimage=(hd0,0)/boot/grub/splash.xpm.gz\nhiddenmenu\ntitle f14-core (2.6.35.10-74.fc14.x86_64)\nroot (hd0,0)\nkernel /boot/vmlinuz-2.6.35.10-74.fc14.x86_64 ro root=LABEL=/\ninitrd /boot/initramfs-2.6.35.10-74.fc14.x86_64.img", 0)

        @plugin.use_labels_for_partitions(guestfs)
      end

      it "should not change anything" do
        guestfs = mock("guestfs")

        guestfs.should_receive(:list_devices).and_return(['/dev/sda'])

        guestfs.should_receive(:read_file).with('/etc/fstab').and_return("LABEL=/ / something\nLABEL=/boot /boot something\n")
        guestfs.should_not_receive(:vfs_label)
        guestfs.should_not_receive(:write_file)

        guestfs.should_receive(:read_file).with('/boot/grub/grub.conf').and_return("default=0\ntimeout=5\nsplashimage=(hd0,0)/boot/grub/splash.xpm.gz\nhiddenmenu\ntitle f14-core (2.6.35.10-74.fc14.x86_64)\nroot (hd0,0)\nkernel /boot/vmlinuz-2.6.35.10-74.fc14.x86_64 ro root=LABEL=/\ninitrd /boot/initramfs-2.6.35.10-74.fc14.x86_64.img")
        guestfs.should_not_receive(:vfs_label)
        guestfs.should_not_receive(:write_file)

        @plugin.use_labels_for_partitions(guestfs)
      end
    end
  end
end

