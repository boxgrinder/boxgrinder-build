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
require 'boxgrinder-core/helpers/log-helper'
require 'guestfs'
require 'rbconfig'
require 'net/http'
require 'uri'
require 'timeout'

module BoxGrinder
  class GuestFSHelper
    def initialize(disks, appliance_config, config, options = {})
      @disks = disks
      @appliance_config = appliance_config
      @config = config
      @log = options[:log] || LogHelper.new
    end

    attr_reader :guestfs

    def hw_virtualization_available?
      @log.trace "Checking if HW virtualization is available..."

      ec2 = false

      begin
        Timeout::timeout(2) { ec2 = Net::HTTP.get_response(URI.parse('http://169.254.169.254/latest/meta-data/ami-id')).code.eql?("200") }
      rescue Exception
      end

      if `egrep '^flags.*(vmx|svm)' /proc/cpuinfo | wc -l`.chomp.strip.to_i > 0 and !ec2
        @log.trace "HW acceleration available."
        return true
      end

      @log.trace "HW acceleration not available."

      false
    end

    # https://issues.jboss.org/browse/BGBUILD-83
    def log_callback
      default_callback = Proc.new do |event, event_handle, buf, array|
        buf.chomp!

        if event == 64
          @log.debug "GFS: #{buf}"
        else
          @log.trace "GFS: #{buf}" unless buf.start_with?('recv_from_daemon', 'send_to_daemon')
        end
      end

      # Guestfs::EVENT_APPLIANCE  => 16
      # Guestfs::EVENT_LIBRARY    => 32
      # Guestfs::EVENT_TRACE      => 64

      # Referencing int instead of constants make it easier to test
      @guestfs.set_event_callback(default_callback, 16 | 32 | 64)

      yield if block_given?
    end

    # If log callback aren't available we will fail to this, which sucks...
    def log_hack
      read_stderr, write_stderr = IO.pipe

      fork do
        write_stderr.close

        read_stderr.each do |l|
          @log.trace "GFS: #{l.chomp.strip}"
        end

        read_stderr.close
      end

      old_stderr = STDERR.clone

      STDERR.reopen(write_stderr)
      STDERR.sync = true

      begin
        # Execute all tasks
        yield if block_given?
      ensure
        STDERR.reopen(old_stderr)
      end

      write_stderr.close
      read_stderr.close

      Process.wait
    end

    def initialize_guestfs(options = {})
      @log.debug "Preparing guestfs..."
      @log.trace "Setting libguestfs temporary directory to '#{@config.dir.tmp}'..."

      FileUtils.mkdir_p(@config.dir.tmp)
      ENV['TMPDIR'] = @config.dir.tmp

      @guestfs = Guestfs::create

      if @guestfs.respond_to?(:set_event_callback)
        @log.trace "We have event callbacks available!"
        log_callback { prepare_guestfs(options) { yield } }
      else
        @log.trace "We don't have event callbacks available :( Falling back to proxy."
        log_hack { prepare_guestfs(options) { yield } }
      end
    end

    def prepare_guestfs(options = {})
      @log.trace "Setting debug + trace..."
      @guestfs.set_verbose(1)
      @guestfs.set_trace(1)

      # https://issues.jboss.org/browse/BGBUILD-246
      memsize = ENV['LIBGUESTFS_MEMSIZE'].nil? ? 300 : ENV['LIBGUESTFS_MEMSIZE'].to_i
      @guestfs.set_memsize(memsize)

      # https://bugzilla.redhat.com/show_bug.cgi?id=502058
      @guestfs.set_append("noapic")

      @log.trace "Enabling SElinux support in guestfs..."
      @guestfs.set_selinux(1)

      unless hw_virtualization_available?
        # This wrapper is required especially for EC2 where running qemu-kvm crashes libguestfs
        qemu_wrapper = "#{File.dirname(__FILE__)}/qemu.wrapper"

        @log.trace "Setting QEMU wrapper to #{qemu_wrapper}..."
        @guestfs.set_qemu(qemu_wrapper)
        @log.trace "QEMU wrapper set."
      end

      @disks.each do |disk|
        @log.trace "Adding drive '#{disk}'..."
        if options[:ide_disk]
          @guestfs.add_drive_with_if(disk, 'ide')
        else
          @guestfs.add_drive(disk)
        end
        @log.trace "Drive added."
      end

      if @guestfs.respond_to?('set_network')
        @log.debug "Enabling networking for GuestFS..."
        @guestfs.set_network(1)
      end

      yield
    end

    def customize(options = {})
      initialize_guestfs(options) do
        helper = execute(options)

        yield @guestfs, helper

        clean_close
      end
    end

    def execute(options = {})
      options = {
          :ide_disk => false,
          :mount_prefix => '',
          :automount => true,
          :load_selinux_policy => true
      }.merge(options)

      @log.debug "Launching guestfs..."
      @guestfs.launch

      if options[:automount]
        device = @guestfs.list_devices.first

        if @guestfs.list_partitions.size == 0
          mount_partition(device, '/', options[:mount_prefix])
        else
          mount_partitions(device, options[:mount_prefix])
        end

        load_selinux_policy if options[:load_selinux_policy]
      end

      @log.trace "Guestfs launched."

      self
    end

    def load_selinux_policy
      return unless @guestfs.exists('/etc/sysconfig/selinux') != 0

      @log.trace "Loading SElinux policy..."

      @guestfs.aug_init("/", 32)
      @guestfs.aug_rm("/augeas/load//incl[. != '/etc/sysconfig/selinux']")
      @guestfs.aug_load

      selinux = @guestfs.aug_get("/files/etc/sysconfig/selinux/SELINUX")

      begin
        @guestfs.sh("/usr/sbin/load_policy") if !selinux.nil? and !selinux.eql?('disabled')
        @log.trace "SElinux policy loaded."
      rescue
        @log.warn "Loading SELinux policy failed. SELinux may be not fully initialized."
      ensure
        @guestfs.aug_close
      end
    end

    def clean_close
      @log.trace "Closing guestfs..."

      @guestfs.sync
      @guestfs.umount_all
      @guestfs.close

      @log.trace "Guestfs closed."
    end

    def mount_partition(part, mount_point, mount_prefix = '')
      @log.trace "Mounting #{part} partition to #{mount_point}..."
      @guestfs.mount_options("", part, "#{mount_prefix}#{mount_point}")
      # By the way - update the labels so we don't have to muck again with partitions
      # this will be done for every mount, but shouldn't hurt too much.
      @guestfs.set_e2label(part, Zlib.crc32(mount_point).to_s(16))
      @log.trace "Partition mounted."
    end

    # This mount partitions. We assume that the first partition is a root partition.
    #
    def mount_partitions(device, mount_prefix = '')
      @log.trace "Mounting partitions..."

      partitions = mountable_partitions(device)
      mount_points = LinuxHelper.new(:log => @log).partition_mount_points(@appliance_config.hardware.partitions)
      partitions.each_index { |i| mount_partition(partitions[i], mount_points[i], mount_prefix) }
    end

    def mountable_partitions(device)
      partitions = @guestfs.list_partitions.reject { |i| !(i =~ /^#{device}/) }

      # we need to remove extended partition
      # extended partition is always #3
      partitions.delete_at(3) if partitions.size > 4

      partitions
    end

    def umount_partition(part)
      @log.trace "Unmounting partition #{part}..."
      @guestfs.umount(part)
      @log.trace "Partition unmounted."
    end

    # Unmounts partitions in reverse order.
    #
    def umount_partitions(device)
      partitions = @guestfs.list_partitions.reject { |i| !(i =~ /^#{device}/) }

      @log.trace "Unmounting partitions..."
      partitions.reverse.each { |part| umount_partition(part) }
      @log.trace "All partitions unmounted."
    end

    def sh(cmd, options = {})
      arch = options[:arch] || `uname -m`.chomp.strip

      @log.debug "Executing '#{cmd}' command..."
      @guestfs.sh("setarch #{arch} << 'SETARCH_EOF'\n#{cmd}\nSETARCH_EOF")
      @log.debug "Command '#{cmd}' executed."
    end

    def augeas(&block)
      AugeasHelper.new(@guestfs, self, :log => @log).edit(&block)
    end
  end
end