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

require 'boxgrinder-build/helpers/guestfs-helper'
require 'rubygems'
require 'rspec'
require 'hashery/opencascade'

module BoxGrinder
  describe GuestFSHelper do
    before(:each) do
      ENV.delete("LIBGUESTFS_MEMSIZE")

      @log = Logger.new('/dev/null')
      @appliance_config = mock('ApplianceConfig')
      @appliance_config.stub!(:hardware).and_return(:partitions => {})

      @config = mock('Config')
      @config.stub!(:dir).and_return(OpenCascade.new(:tmp => '/tmp'))

      @helper = GuestFSHelper.new('a/raw/disk', @appliance_config, @config, :log => @log)
    end

    describe ".prepare_guestfs" do
      it "should prepare guestfs with normal disk" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)
        guestfs.should_receive(:set_memsize).with(300)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)

        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)

        @helper.prepare_guestfs(:a => :b) do
        end
      end

      it "should prepare and run guestfs wid IDE disk" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)
        guestfs.should_receive(:set_memsize).with(300)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)

        guestfs.should_receive(:add_drive_with_if).with('a/raw/disk', 'ide')
        guestfs.should_receive(:set_network).with(1)

        @helper.prepare_guestfs(:ide_disk => true) {}
      end

      it "should prepare guestfs without HW accelerarion enabled" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)
        guestfs.should_receive(:set_memsize).with(300)

        @helper.should_receive(:hw_virtualization_available?).and_return(false)

        guestfs.should_receive(:set_qemu).with(/\/qemu\.wrapper$/)
        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)

        @helper.prepare_guestfs {}
      end
      
      it "should prepare guestfs with custom memory settings" do
        ENV['LIBGUESTFS_MEMSIZE'] = "500"

        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:set_append).with('noapic')
        guestfs.should_receive(:set_verbose)
        guestfs.should_receive(:set_trace)
        guestfs.should_receive(:set_selinux).with(1)
        guestfs.should_receive(:set_memsize).with(500)

        @helper.should_receive(:hw_virtualization_available?).and_return(true)

        guestfs.should_receive(:add_drive).with('a/raw/disk')
        guestfs.should_receive(:set_network).with(1)

        @helper.prepare_guestfs {}
      end
    end

    describe ".initialize_guestfs" do
      it "should initialize the guestfs env with callback support" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:respond_to?).with(:set_event_callback).and_return(true)
        @helper.should_receive(:log_callback)

        FileUtils.should_receive(:mkdir_p).with('/tmp')
        Guestfs.should_receive(:create).and_return(guestfs)

        @helper.initialize_guestfs
      end

      it "should initialize the guestfs env without callback support" do
        guestfs = mock('Guestfs')
        guestfs.should_receive(:respond_to?).with(:set_event_callback).and_return(false)
        @helper.should_receive(:log_hack)

        FileUtils.should_receive(:mkdir_p).with('/tmp')
        Guestfs.should_receive(:create).and_return(guestfs)

        @helper.initialize_guestfs
      end
    end

    describe ".execute" do
      it "should run guestfs with one partition" do
        @appliance_config.stub!(:hardware).and_return(:partitions => {'/' => nil})

        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_devices).and_return(['/dev/vda'])
        guestfs.should_receive(:list_partitions).and_return(['/dev/vda1'])

        @helper.should_receive(:mount_partitions).with("/dev/vda", '')
        @helper.should_receive(:load_selinux_policy)

        @helper.execute
      end

      it "should run guestfs with two partitions" do
        @appliance_config.stub!(:hardware).and_return(OpenCascade.new(:partitions => {'/' => nil, '/home' => nil}))

        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_devices).and_return(['/dev/vda'])
        guestfs.should_receive(:list_partitions).and_return(['/dev/vda1', '/dev/vda2'])

        @helper.should_receive(:mount_partitions).with("/dev/vda", "")
        @helper.should_receive(:load_selinux_policy)

        @helper.execute
      end

      it "should run guestfs with no partitions and don't load selinux" do
        @appliance_config.stub!(:hardware).and_return(OpenCascade.new(:partitions => {'/' => nil, '/home' => nil}))

        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:launch)
        guestfs.should_receive(:list_devices).and_return(['/dev/vda'])
        guestfs.should_receive(:list_partitions).and_return([])

        @helper.should_receive(:mount_partition).with("/dev/vda", "/", "")
        @helper.should_not_receive(:load_selinux_policy)

        @helper.execute(:load_selinux_policy => false)
      end
    end

    it "should close guestfs in clean way" do
      guestfs = mock('Guestfs')

      guestfs.should_receive(:sync)
      guestfs.should_receive(:umount_all)
      guestfs.should_receive(:close)

      @helper.instance_variable_set(:@guestfs, guestfs)

      @helper.clean_close
    end

    describe ".mount_partition" do
      it "should mount root partition" do
        guestfs = mock('Guestfs')

        guestfs.should_receive(:mount_options).with("", "/dev/sda", "/")
        guestfs.should_receive(:set_e2label).with("/dev/sda", "79d3d2d4")

        @helper.instance_variable_set(:@guestfs, guestfs)
        @helper.mount_partition("/dev/sda", "/")
      end

      it "should mount home partition" do
        guestfs = mock('Guestfs')

        guestfs.should_receive(:mount_options).with("", "/dev/sda", "/home")
        guestfs.should_receive(:set_e2label).with("/dev/sda", "d5219c04")

        @helper.instance_variable_set(:@guestfs, guestfs)
        @helper.mount_partition("/dev/sda", "/home")
      end
    end

    describe ".mount_partitions" do
      it "should mount two partitions" do
        guestfs = mock('Guestfs')

        @appliance_config.stub!(:hardware).and_return(OpenCascade.new(:partitions => {'/' => nil, '/home' => nil}))
        guestfs.should_receive(:list_partitions).and_return(['/dev/vda1', '/dev/vda2'])

        @helper.should_receive(:mount_partition).with('/dev/vda1', '/', '')
        @helper.should_receive(:mount_partition).with('/dev/vda2', '/home', '')

        @helper.instance_variable_set(:@guestfs, guestfs)
        @helper.mount_partitions('/dev/vda')
      end

      it "should mount partitions with extended partitions" do
        guestfs = mock('Guestfs')

        @appliance_config.stub!(:hardware).and_return(OpenCascade.new(:partitions => {'/' => nil, '/home' => nil, '/var/www' => nil, '/var/mock' => nil}))
        guestfs.should_receive(:list_partitions).and_return(['/dev/vda1', '/dev/vda2', '/dev/vda3', '/dev/vda4', '/dev/vda5'])

        @helper.should_receive(:mount_partition).with('/dev/vda1', '/', '')
        @helper.should_receive(:mount_partition).with('/dev/vda2', '/home', '')
        @helper.should_receive(:mount_partition).with('/dev/vda3', '/var/www', '')
        @helper.should_receive(:mount_partition).with('/dev/vda5', '/var/mock', '')

        @helper.instance_variable_set(:@guestfs, guestfs)
        @helper.mount_partitions('/dev/vda')
      end
    end

    it "execute a command for current arch" do
      guestfs = mock('Guestfs')

      @helper.should_receive(:`).with('uname -m').and_return('bleh')
      @helper.instance_variable_set(:@guestfs, guestfs)

      guestfs.should_receive(:sh).with("setarch bleh << 'SETARCH_EOF'\ncommand\nSETARCH_EOF")

      @helper.sh("command")
    end

    it "execute a command for specified arch" do
      guestfs = mock('Guestfs')
      @helper.instance_variable_set(:@guestfs, guestfs)

      guestfs.should_receive(:sh).with("setarch arch << 'SETARCH_EOF'\ncommand\nSETARCH_EOF")

      @helper.sh("command", :arch => 'arch')
    end

    describe ".hw_virtualization_available?" do
      it "should return true if HW acceleration is available" do
        URI.should_receive(:parse).with('http://169.254.169.254/latest/meta-data/ami-id').and_return('parsed')
        Net::HTTP.should_receive(:get_response).with("parsed").and_return(OpenCascade.new(:code => '404'))
        @helper.should_receive(:`).with("egrep '^flags.*(vmx|svm)' /proc/cpuinfo | wc -l").and_return("2")
        @helper.hw_virtualization_available?.should == true
      end

      it "should return false if no vmx flag is present" do
        URI.should_receive(:parse).with('http://169.254.169.254/latest/meta-data/ami-id').and_return('parsed')
        Net::HTTP.should_receive(:get_response).with("parsed").and_return(OpenCascade.new(:code => '404'))
        @helper.should_receive(:`).with("egrep '^flags.*(vmx|svm)' /proc/cpuinfo | wc -l").and_return("0")
        @helper.hw_virtualization_available?.should == false
      end

      it "should return false if we're on EC2" do
        URI.should_receive(:parse).with('http://169.254.169.254/latest/meta-data/ami-id').and_return('parsed')
        Net::HTTP.should_receive(:get_response).with("parsed").and_return(OpenCascade.new(:code => '200'))
        @helper.hw_virtualization_available?.should == false
      end

      it "should return false if we're NOT on EC2 and AMI id retrieval raised an exception" do
        URI.should_receive(:parse).with('http://169.254.169.254/latest/meta-data/ami-id').and_return('parsed')
        Net::HTTP.should_receive(:get_response).with("parsed").and_raise "Boom"
        @helper.hw_virtualization_available?.should == false
      end
    end

    describe ".load_selinux_policy" do
      it "should load SElinux policy for SElinux enabled guests" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(1)
        guestfs.should_receive(:aug_init).with("/", 32)
        guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/sysconfig/selinux']")
        guestfs.should_receive(:aug_load)
        guestfs.should_receive(:aug_get).with("/files/etc/sysconfig/selinux/SELINUX").and_return('permissive')
        guestfs.should_receive(:sh).with("/usr/sbin/load_policy")
        guestfs.should_receive(:aug_close)

        @helper.load_selinux_policy
      end

      it "should not load SElinux policy for SElinux disabled guests" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:exists).with('/etc/sysconfig/selinux').and_return(1)
        guestfs.should_receive(:aug_init).with("/", 32)
        guestfs.should_receive(:aug_rm).with("/augeas/load//incl[. != '/etc/sysconfig/selinux']")
        guestfs.should_receive(:aug_load)
        guestfs.should_receive(:aug_get).with("/files/etc/sysconfig/selinux/SELINUX").and_return('disabled')
        guestfs.should_not_receive(:sh).with("/usr/sbin/load_policy")
        guestfs.should_receive(:aug_close)

        @helper.load_selinux_policy
      end
    end

    describe ".umount_partitions" do
      it "should umount partitions" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)

        guestfs.should_receive(:list_partitions).and_return(['/dev/vda1', '/dev/vda2'])

        @helper.should_receive(:umount_partition).ordered.with('/dev/vda2')
        @helper.should_receive(:umount_partition).ordered.with('/dev/vda1')

        @helper.umount_partitions('/dev/vda')
      end
    end

    describe ".umount_partition" do
      it "should umount partition" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)
        guestfs.should_receive(:umount).with('/dev/vda1')
        @helper.umount_partition('/dev/vda1')
      end
    end

    describe ".customize" do
      it "should execute customize wihout issues" do
        @helper.should_receive(:initialize_guestfs).and_yield
        @helper.should_receive(:clean_close)
        @helper.should_receive(:execute).with(:a => :b)

        @helper.customize(:a => :b) do |guestfs, guestfs_helper|
        end
      end
    end

    describe ".log_callback" do
      it "should register callback for all 3 events" do
        guestfs = mock('Guestfs')
        @helper.instance_variable_set(:@guestfs, guestfs)
        guestfs.should_receive(:set_event_callback).with(an_instance_of(Proc), 16 | 32 | 64)
        @helper.log_callback
      end
    end

    describe ".log_hack" do
      it "should register callback for all 3 events" do
        guestfs = mock('Guestfs')
        pread = ['a', 'b']
        pwrite = mock('pwrite')
        old_stderr = mock('old_stderr')

        IO.should_receive(:pipe).and_return([pread, pwrite])
        STDERR.should_receive(:clone).and_return(old_stderr)
        STDERR.should_receive(:reopen).with(pwrite)
        STDERR.should_receive(:reopen).with(old_stderr)

        pread.should_receive(:close)
        pwrite.should_receive(:close)

        Process.should_receive(:wait)

        @helper.should_receive(:fork)
        @helper.log_hack
      end
    end
  end
end