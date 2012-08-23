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

require 'boxgrinder-build/plugins/os/fedora/fedora-plugin'
require 'boxgrinder-core/astruct'

module BoxGrinder
  describe FedoraPlugin do
    before(:each) do
      @config = mock('Config')
      @config.stub!(:os_config).and_return({})
      plugins = mock('Plugins')
      plugins.stub!(:[]).with('fedora').and_return({})
      @config.stub!(:[]).with(:plugins).and_return(plugins)

      @appliance_config = mock('ApplianceConfig')

      @appliance_config.stub!(:path).and_return(OpenCascade.new({:build => 'build/path'}))
      @appliance_config.stub!(:name).and_return('full')
      @appliance_config.stub!(:version).and_return(1)
      @appliance_config.stub!(:release).and_return(0)
      @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '13'}))
      @appliance_config.stub!(:hardware).and_return(OpenCascade.new({:arch => 'x86_64'}))
      @appliance_config.stub!(:is64bit?).and_return(true)
      @appliance_config.stub!(:packages).and_return(['mc'])

      @plugin = FedoraPlugin.new.init(@config, @appliance_config, {:class => BoxGrinder::FedoraPlugin, :type => :os, :name => :fedora, :full_name => "Fedora", :versions => ["11", "12", "13", "14", "rawhide"]}, :log => LogHelper.new(:level => :trace, :type => :stdout))

      @config = @plugin.instance_variable_get(:@config)
      @appliance_config = @plugin.instance_variable_get(:@appliance_config)
      @exec_helper = @plugin.instance_variable_get(:@exec_helper)
      @log = @plugin.instance_variable_get(:@log)


      @plugin_config = @plugin.instance_variable_get(:@plugin_config).merge(
          {
              'access_key' => 'access_key',
              'secret_access_key' => 'secret_access_key',
              'bucket' => 'bucket',
              'account_number' => '0000-0000-0000',
              'cert_file' => '/path/to/cert/file',
              'key_file' => '/path/to/key/file'
          }
      )

      @plugin.instance_variable_set(:@plugin_config, @plugin_config)
    end

    it "should normalize packages for 32bit for pae enabled system" do
      @appliance_config.stub!(:os).and_return(OpenCascade.new(:name => 'fedora', :version => '13'))
      @plugin_config.merge!('PAE' => false)

      packages = ['abc', 'def', 'kernel']

      @appliance_config.should_receive(:is64bit?).and_return(false)

      @plugin.normalize_packages(packages)
      packages.should == ["abc", "def", "@core", "system-config-firewall-base", "dhclient", "kernel", "grub"]
    end

    it "should normalize packages for Fedora 16" do
      @appliance_config.stub!(:os).and_return(OpenCascade.new(:name => 'fedora', :version => '16'))

      packages = ['abc', 'def', 'kernel']

      @plugin.normalize_packages(packages)
      packages.should == ["abc", "def", "@core", "system-config-firewall-base", "dhclient", "kernel", "grub2"]
    end

    it "should normalize packages for 64bit" do
      packages = ['abc', 'def', 'kernel']

      @plugin.normalize_packages(packages)
      packages.should == ["abc", "def", "@core", "system-config-firewall-base", "dhclient", "kernel", "grub"]
    end

    it "should add packages for fedora 13" do
      packages = []

      @plugin.normalize_packages(packages)
      packages.should == ["@core", "system-config-firewall-base", "dhclient", "kernel", "grub"]
    end

    context "BGBUILD-204" do
      it "should disable bios device name hints for GRUB legacy" do
        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/boot/grub2/grub.cfg").and_return(0)
        guestfs.should_receive(:exists).with("/boot/grub/grub.conf").and_return(1)
        guestfs.should_receive(:sh).with("sed -i \"s/kernel\\(.*\\)/kernel\\1 biosdevname=0/g\" /boot/grub/grub.conf")
        @plugin.disable_biosdevname(guestfs)
      end

      it "should disable bios device name hints for GRUB2" do
        guestfs = mock("GuestFS")
        guestfs.should_receive(:exists).with("/boot/grub2/grub.cfg").and_return(1)
        guestfs.should_receive(:exists).with("/boot/grub/grub.conf").and_return(0)
        guestfs.should_receive(:write).with("/etc/default/grub", "GRUB_CMDLINE_LINUX=\"quiet rhgb biosdevname=0\"\n")
        guestfs.should_receive(:sh).with("cd / && grub2-mkconfig -o /boot/grub2/grub.cfg")
        @plugin.disable_biosdevname(guestfs)
      end

      it "should change to runlevel 3 by default" do
        guestfs = mock("GuestFS")
        guestfs.should_receive(:rm).with("/etc/systemd/system/default.target")
        guestfs.should_receive(:ln_sf).with("/lib/systemd/system/multi-user.target", "/etc/systemd/system/default.target")
        @plugin.change_runlevel(guestfs)
      end

      it "should disable netfs" do
        guestfs = mock("GuestFS")
        guestfs.should_receive(:sh).with("chkconfig netfs off")
        @plugin.disable_netfs(guestfs)
      end
    end

    it "should link /etc/mtab to /proc/self/mounts" do
      guestfs = mock("GuestFS")
      guestfs.should_receive(:ln_sf).with("/proc/self/mounts", "/etc/mtab")
      @plugin.link_mtab(guestfs)
    end

    describe ".execute" do
      it "should make Fedora 15 or higher work" do
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '15'}))

        guestfs = mock("GuestFS")
        guestfs_helper = mock("GuestFSHelper")

        @plugin.should_receive(:normalize_packages).ordered
        @plugin.should_receive(:disable_biosdevname).ordered.with(guestfs)
        @plugin.should_receive(:change_runlevel).ordered.with(guestfs)
        @plugin.should_receive(:disable_netfs).ordered.with(guestfs)
        @plugin.should_receive(:link_mtab).ordered.with(guestfs)

        @plugin.should_receive(:build_with_appliance_creator).with("file", an_instance_of(Hash)).and_yield(guestfs, guestfs_helper)
        @plugin.execute("file")
      end

      # https://issues.jboss.org/browse/BGBUILD-298
      it "should for Fedora 16 or higher first install GRUB2 then look after it" do
        @appliance_config.stub!(:os).and_return(OpenCascade.new({:name => 'fedora', :version => '16'}))

        guestfs = mock("GuestFS")
        guestfs_helper = mock("GuestFSHelper")

        @plugin.should_receive(:normalize_packages).ordered
        @plugin.should_receive(:disable_biosdevname).ordered.with(guestfs)
        @plugin.should_receive(:change_runlevel).ordered.with(guestfs)
        @plugin.should_receive(:disable_netfs).ordered.with(guestfs)
        @plugin.should_receive(:link_mtab).ordered.with(guestfs)

        @plugin.should_receive(:build_with_appliance_creator).with("file", an_instance_of(Hash)).and_yield(guestfs, guestfs_helper)
        @plugin.execute("file")
      end
    end
  end
end

