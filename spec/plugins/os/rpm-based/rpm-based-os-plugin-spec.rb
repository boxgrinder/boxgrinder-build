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
require 'boxgrinder-core/astruct'

module BoxGrinder
  describe RPMBasedOSPlugin do
    before(:each) do
      @config = mock('Config')
      @appliance_config = mock('ApplianceConfig')
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('rpm_based').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)
      @config.stub!(:dir).and_return(AStruct.new(:tmp => 'tmpdir', :cache => 'cachedir'))
      @config.stub!(:os).and_return(AStruct.new(:name => 'fedora', :version => '14'))
      @config.stub!(:os_config).and_return({})

      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:post).and_return({})
      @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'fedora', :version => '11'}))
      @appliance_config.stub!(:hardware).and_return(AStruct.new(:cpus => 1, :memory => 512, :partitions => {'/' => nil, '/home' => nil}))
      @appliance_config.stub!(:path).and_return(AStruct.new(:build => 'build/path', :main => 'mainpath'))
      @appliance_config.stub!(:files).and_return({})

      @plugin = RSpecPluginHelper.new(RPMBasedOSPlugin).prepare(@config, @appliance_config, :plugin_info => {:class => BoxGrinder::RPMBasedOSPlugin, :type => :os, :name => :rpm_based})

      @config = @plugin.instance_variable_get(:@config)
      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @image_helper = @plugin.instance_variable_get(:@image_helper)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)
    end

    it "should create the /etc/yum.repos.d directory if it does not exist" do
      @appliance_config.stub!(:repos).and_return([
        {'name' => 'cirras', 'baseurl' => "http://repo.boxgrinder.org/packages/fedora/11/RPMS/x86_64"}
      ])

      guestfs = mock("guestfs").as_null_object

      guestfs.stub!(:exists).and_return(0)
      guestfs.should_receive(:mkdir_p).with("/etc/yum.repos.d/")

      @plugin.install_repos(guestfs)
    end

    it "should install repos" do
      @appliance_config.should_receive(:repos).and_return(
          [
              {'name' => 'cirras', 'baseurl' => "http://repo.boxgrinder.org/packages/fedora/11/RPMS/x86_64"},
              {'name' => 'abc', 'baseurl' => 'http://abc', 'mirrorlist' => "http://abc.org/packages/fedora/11/RPMS/x86_64"},
          ])

      guestfs = mock("guestfs").as_null_object

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

      guestfs = mock("guestfs").as_null_object
      guestfs.should_receive(:write_file).with("/etc/yum.repos.d/abc.repo", "[abc]\nname=abc\nenabled=1\ngpgcheck=0\nbaseurl=http://abc\nmirrorlist=http://abc.org/packages/fedora/11/RPMS/x86_64\n", 0)

      @plugin.install_repos(guestfs)
    end

    describe ".use_labels_for_partitions" do
      it "should use labels for partitions instead of paths" do
        guestfs = mock("guestfs")

        guestfs.should_receive(:list_devices).and_return(['/dev/hda'])
        guestfs.should_receive(:exists).with('/boot/grub/grub.conf').and_return(1)
        guestfs.should_receive(:ln_sf).with("/boot/grub/grub.conf", "/etc/grub.conf")

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
        guestfs.should_receive(:exists).with('/boot/grub/grub.conf').and_return(1)

        guestfs.should_receive(:read_file).with('/etc/fstab').and_return("LABEL=/ / something\nLABEL=/boot /boot something\n")
        guestfs.should_not_receive(:vfs_label)
        guestfs.should_not_receive(:write_file)

        guestfs.should_receive(:read_file).with('/boot/grub/grub.conf').and_return("default=0\ntimeout=5\nsplashimage=(hd0,0)/boot/grub/splash.xpm.gz\nhiddenmenu\ntitle f14-core (2.6.35.10-74.fc14.x86_64)\nroot (hd0,0)\nkernel /boot/vmlinuz-2.6.35.10-74.fc14.x86_64 ro root=LABEL=/\ninitrd /boot/initramfs-2.6.35.10-74.fc14.x86_64.img")
        guestfs.should_not_receive(:vfs_label)
        guestfs.should_not_receive(:write_file)

        @plugin.use_labels_for_partitions(guestfs)
      end
    end

    it "should disable the firewall" do
      guestfs = mock("guestfs")
      guestfs.should_receive(:sh).with('lokkit -q --disabled')

      @plugin.disable_firewall(guestfs)
    end

    describe ".build_with_appliance_creator" do
      def do_build
        kickstart = mock(Kickstart)
        kickstart.should_receive(:create).and_return('kickstart.ks')

        validator = mock(RPMDependencyValidator)
        validator.should_receive(:resolve_packages)

        Kickstart.should_receive(:new).with(@config, @appliance_config, {:tmp=>"build/path/rpm_based-plugin/tmp", :base=>"build/path/rpm_based-plugin"}, :log => @log).and_return(kickstart)
        RPMDependencyValidator.should_receive(:new).and_return(validator)

        @exec_helper.should_receive(:execute).with("appliance-creator -d -v -t 'build/path/rpm_based-plugin/tmp' --cache=cachedir/rpms-cache/mainpath --config 'kickstart.ks' -o 'build/path/rpm_based-plugin/tmp' --name 'full' --vmem 512 --vcpu 1 --format raw")

        FileUtils.should_receive(:mv)
        FileUtils.should_receive(:rm_rf)

        guestfs = mock("GuestFS")
        guestfs_helper = mock("GuestFSHelper")

        @image_helper.should_receive(:customize).with(["build/path/rpm_based-plugin/tmp/full-sda.raw"]).and_yield(guestfs, guestfs_helper)

        guestfs.should_receive(:upload).with("/etc/resolv.conf", "/etc/resolv.conf")

        @plugin.should_receive(:change_configuration).with(guestfs_helper)
        @plugin.should_receive(:apply_root_password).with(guestfs)
        @plugin.should_receive(:set_label_for_swap_partitions).with(guestfs, guestfs_helper)
        @plugin.should_receive(:use_labels_for_partitions).with(guestfs)
        @plugin.should_receive(:disable_firewall).with(guestfs)
        @plugin.should_receive(:set_motd).with(guestfs)
        @plugin.should_receive(:install_repos).with(guestfs)

        guestfs.should_receive(:exists).with('/etc/init.d/firstboot').and_return(1)
        guestfs.should_receive(:sh).with('chkconfig firstboot off')

        yield guestfs, guestfs_helper if block_given?
      end

      it "should build appliance" do
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'fedora', :version => '14'}))
        @appliance_config.should_receive(:default_repos).and_return(true)
        @plugin.should_receive(:add_repos).with({})
        do_build
        @plugin.build_with_appliance_creator('jeos.appl')
      end

      it "should execute additional steps for Fedora 15" do
        @appliance_config.stub!(:os).and_return(AStruct.new({:name => 'fedora', :version => '15'}))
        @appliance_config.should_receive(:default_repos).and_return(true)
        @plugin.should_receive(:add_repos).ordered.with({})

        do_build do |guestfs, guestfs_helper|
          @plugin.should_receive(:recreate_rpm_database).ordered.with(guestfs, guestfs_helper)
          @plugin.should_receive(:execute_post).ordered.with(guestfs_helper)
        end

        @plugin.build_with_appliance_creator('jeos.appl')
      end
    end

    describe ".add_repos" do
      it "should add specified repos to appliance" do
        repos = []

        @appliance_config.stub!(:variables).and_return({'OS_VERSION' => '11', 'BASE_ARCH' => 'i386'})
        @appliance_config.stub!(:repos).and_return(repos)

        @plugin.add_repos({
          "11" => {
              "base" => {
                  "mirrorlist" => "http://mirrorlist.centos.org/?release=#OS_VERSION#&arch=#BASE_ARCH#&repo=os"
              }
          }
        })

        repos.size.should == 1
        repos.first['mirrorlist'].should == 'http://mirrorlist.centos.org/?release=11&arch=i386&repo=os'

      end

      it "should not fail with empty repos" do
        @plugin.add_repos({})
      end
    end

    describe ".execute_appliance_creator" do
      it "should execute appliance creator successfuly" do
        @exec_helper.should_receive(:execute).with("appliance-creator -d -v -t 'build/path/rpm_based-plugin/tmp' --cache=cachedir/rpms-cache/mainpath --config 'kickstart.ks' -o 'build/path/rpm_based-plugin/tmp' --name 'full' --vmem 512 --vcpu 1 --format raw")
        @plugin.execute_appliance_creator('kickstart.ks')
      end

      it "should catch the interrupt and unmount the appliance-creator mounts" do
        @exec_helper.should_receive(:execute).with("appliance-creator -d -v -t 'build/path/rpm_based-plugin/tmp' --cache=cachedir/rpms-cache/mainpath --config 'kickstart.ks' -o 'build/path/rpm_based-plugin/tmp' --name 'full' --vmem 512 --vcpu 1 --format raw").and_raise(InterruptionError.new(12345))
        @plugin.should_receive(:cleanup_after_appliance_creator).with(12345)
        @plugin.should_receive(:abort)
        @plugin.execute_appliance_creator('kickstart.ks')
      end
    end

    describe ".cleanup_after_appliance_creator" do
      it "should cleanup after appliance creator (surprisingly!)" do
        Process.should_receive(:kill).with("TERM", 12345)
        Process.should_receive(:wait).with(12345)

        Dir.should_receive(:[]).with('build/path/rpm_based-plugin/tmp/imgcreate-*').and_return(['adir'])

        @exec_helper.should_receive(:execute).ordered.with("mount | grep adir | awk '{print $1}'").and_return("/dev/mapper/loop0p1
/dev/mapper/loop0p2
/sys
/proc
/dev/pts
/dev/shm
/var/cache/boxgrinder/rpms-cache/x86_64/fedora/14")

        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/var/cache/yum')
        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/dev/shm')
        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/dev/pts')
        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/proc')
        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/sys')
        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/home')
        @exec_helper.should_receive(:execute).ordered.with('umount -d adir/install_root/')

        @exec_helper.should_receive(:execute).ordered.with("/sbin/kpartx -d /dev/loop0")
        @exec_helper.should_receive(:execute).ordered.with("losetup -d /dev/loop0")

        @exec_helper.should_receive(:execute).ordered.with("rm /dev/loop01")
        @exec_helper.should_receive(:execute).ordered.with("rm /dev/loop02")

        @plugin.cleanup_after_appliance_creator(12345)
      end
    end

    describe ".recreate_rpm_database" do
      it "should recreate RPM database" do
        guestfs = mock("GuestFS")
        guestfs_helper = mock("GuestFSHelper")

        guestfs.should_receive(:download).with("/var/lib/rpm/Packages", "build/path/rpm_based-plugin/tmp/Packages")
        @exec_helper.should_receive(:execute).with("/usr/lib/rpm/rpmdb_dump build/path/rpm_based-plugin/tmp/Packages > build/path/rpm_based-plugin/tmp/Packages.dump")
        guestfs.should_receive(:upload).with("build/path/rpm_based-plugin/tmp/Packages.dump", "/tmp/Packages.dump")
        guestfs.should_receive(:sh).with("rm -rf /var/lib/rpm/*")
        guestfs_helper.should_receive(:sh).with("cd /var/lib/rpm/ && cat /tmp/Packages.dump | /usr/lib/rpm/rpmdb_load Packages")
        guestfs_helper.should_receive(:sh).with("rpm --rebuilddb")

        @plugin.recreate_rpm_database(guestfs, guestfs_helper)
      end
    end

    describe ".install_files" do
      it "should install files with relative paths" do
        @appliance_config.stub!(:files).and_return("/opt" => ['abc', 'def'])
        @plugin.instance_variable_set(:@appliance_definition_file, "file")

        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/opt").once.and_return(1)
        guestfs.should_receive(:tar_in).with("/tmp/bg_install_files.tar", "/opt")

        File.stub!(:exists?)
        File.should_receive(:exists?).with('./abc').and_return(true)
        File.should_receive(:exists?).with('./def').and_return(true)

        @exec_helper.should_receive(:execute).with("cd . && tar -cvf /tmp/bg_install_files.tar --wildcards abc def")

        @plugin.install_files(guestfs)
      end

      it "should install files with absolute paths" do
        @appliance_config.stub!(:files).and_return("/opt" => ['/opt/abc', '/opt/def'])
        @plugin.instance_variable_set(:@appliance_definition_file, "file")

        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/opt").once.and_return(1)
        guestfs.should_receive(:tar_in).with("/tmp/bg_install_files.tar", "/opt")

        File.stub!(:exists?)
        File.should_receive(:exists?).with('/opt/abc').and_return(true)
        File.should_receive(:exists?).with('/opt/def').and_return(true)

        @exec_helper.should_receive(:execute).with("cd . && tar -cvf /tmp/bg_install_files.tar --wildcards /opt/abc /opt/def")

        @plugin.install_files(guestfs)
      end

      it "should install files with remote paths" do
        @appliance_config.stub!(:files).and_return("/opt" => ['http://somehost/file.zip', 'https://somehost/something.tar.gz', 'ftp://somehost/ftp.txt'])
        @plugin.instance_variable_set(:@appliance_definition_file, "file")

        guestfs = mock("GuestFS")

        guestfs.should_receive(:exists).with("/opt").once.and_return(1)
        guestfs.should_receive(:sh).with("cd /opt && curl -O -L http://somehost/file.zip")
        guestfs.should_receive(:sh).with("cd /opt && curl -O -L https://somehost/something.tar.gz")
        guestfs.should_receive(:sh).with("cd /opt && curl -O -L ftp://somehost/ftp.txt")

        @plugin.install_files(guestfs)
      end

      it "should create the destination directory if it doesn't exists" do
        @appliance_config.stub!(:files).and_return("/opt/aaa" => ['abc'])
        @plugin.instance_variable_set(:@appliance_definition_file, "file")

        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/opt/aaa").and_return(0)
        guestfs.should_receive(:mkdir_p).with("/opt/aaa")
        guestfs.should_receive(:tar_in).with("/tmp/bg_install_files.tar", "/opt/aaa")

        File.stub!(:exists?)
        File.should_receive(:exists?).with('./abc').and_return(true)

        @exec_helper.should_receive(:execute).with("cd . && tar -cvf /tmp/bg_install_files.tar --wildcards abc")

        @plugin.install_files(guestfs)
      end

      it "should upload files when correctly when appliance definition file is not in current directory" do
        @appliance_config.stub!(:files).and_return("/opt/aaa" => ['abc', '/blah/def'])
        @plugin.instance_variable_set(:@appliance_definition_file, "some/dir/to/file.appl")

        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/opt/aaa").and_return(0)
        guestfs.should_receive(:mkdir_p).with("/opt/aaa")
        guestfs.should_receive(:tar_in).with("/tmp/bg_install_files.tar", "/opt/aaa")

        File.stub!(:exists?)
        File.should_receive(:exists?).with('some/dir/to/abc').and_return(true)
        File.should_receive(:exists?).with('/blah/def').and_return(true)

        @exec_helper.should_receive(:execute).with("cd some/dir/to && tar -cvf /tmp/bg_install_files.tar --wildcards abc /blah/def")

        @plugin.install_files(guestfs)
      end

      it "should raise if file doesn't exists" do
        @appliance_config.stub!(:files).and_return("/opt/aaa" => ['abc', '/blah/def'])
        @plugin.instance_variable_set(:@appliance_definition_file, "some/dir/to/file.appl")

        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/opt/aaa").and_return(0)
        guestfs.should_receive(:mkdir_p).with("/opt/aaa")

        File.stub!(:exists?)
        File.should_receive(:exists?).with('some/dir/to/abc').and_return(false)

        lambda { @plugin.install_files(guestfs) }.should raise_error(ValidationError, "File 'abc' specified in files section of appliance definition file doesn't exists.")
      end
    end

    describe ".set_label_for_swap_partitions" do
      it "should NOT set label for any partition" do
        guestfs = mock("GuestFS")
        guestfs_helper = mock("GuestFSHelper")

        guestfs_helper.should_receive(:mountable_partitions).with('/dev/sda', :list_swap => true).and_return(['/dev/sda1', '/dev/sda2'])

        guestfs.should_receive(:list_devices).and_return(['/dev/sda'])
        guestfs.should_receive(:vfs_type).with('/dev/sda1').and_return('ext3')
        guestfs.should_receive(:vfs_type).with('/dev/sda2').and_return('ext4')
        guestfs.should_not_receive(:set_e2label)

        @plugin.set_label_for_swap_partitions(guestfs, guestfs_helper)
      end

      it "should set label for swap partition" do
        guestfs = mock("GuestFS")
        guestfs_helper = mock("GuestFSHelper")

        guestfs_helper.should_receive(:mountable_partitions).with('/dev/sda', :list_swap => true).and_return(['/dev/sda1', '/dev/sda2'])

        guestfs.should_receive(:list_devices).and_return(['/dev/sda'])
        guestfs.should_receive(:vfs_type).with('/dev/sda1').and_return('ext3')
        guestfs.should_receive(:vfs_type).with('/dev/sda2').and_return('swap')
        guestfs.should_receive(:mkswap_L).with('swap', '/dev/sda2')

        @plugin.set_label_for_swap_partitions(guestfs, guestfs_helper)
      end
    end

    it "should link /boot/grub/grub.conf to /etc/grub.conf" do
      guestfs = mock("GuestFS")
      guestfs.should_receive(:ln_sf).with("/boot/grub/grub.conf", "/etc/grub.conf")
      @plugin.link_grubconf(guestfs)
    end
  end
end
