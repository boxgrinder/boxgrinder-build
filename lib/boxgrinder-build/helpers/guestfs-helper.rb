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
require 'resolv'

module BoxGrinder
  class SilencerProxy
    def initialize(o, destination)
      @o = o
      @destination = destination
    end

    def method_missing(m, *args, &block)
      begin
        redirect_streams(@destination) do
          @o.send(m, *args, &block)
        end
      rescue
        raise
      end
    end

    def redirect_streams(destination)
      old_stdout_stream = STDOUT.dup
      old_stderr_stream = STDERR.dup

      STDOUT.reopen(destination)
      STDERR.reopen(destination)

      STDOUT.sync = true
      STDERR.sync = true

      yield
    ensure
      STDOUT.reopen(old_stdout_stream)
      STDERR.reopen(old_stderr_stream)
    end
  end
end

module Guestfs
  class Guestfs
    alias_method :sh_original, :sh

    def sh(command)
      begin
        output = sh_original(command)
        puts output
      rescue => e
        puts "Error occurred while executing above command, aborting."
        raise e
      end

      output
    end

    def redirect(destination)
      BoxGrinder::SilencerProxy.new(self, destination)
    end
  end
end

module BoxGrinder
  class GuestFSHelper
    def initialize(raw_disk, options = {})
      @raw_disk = raw_disk
      @log = options[:log] || LogHelper.new

      @partitions = {}
    end

    attr_reader :guestfs

    def hw_virtualization_available?
      @log.trace "Checking if HW virtualization is available..."

      begin
        ec2 = Resolv.getname("169.254.169.254").include?(".ec2.internal")
      rescue Resolv::ResolvError
        ec2 = false
      end

      if `cat /proc/cpuinfo | grep flags | grep vmx | wc -l`.chomp.strip.to_i > 0 and !ec2
        @log.trace "HW acceleration available."
        return true
      end

      @log.trace "HW acceleration not available."

      false
    end

    def customize(options = {})
      read_pipe, write_pipe = IO.pipe

      fork do
        read_pipe.each do |o|
          if o.chomp.strip.eql?("<EOF>")
            exit
          else
            @log.trace "GFS: #{o.chomp.strip}"
          end
        end
      end

      helper = execute(write_pipe, options)

      yield @guestfs, helper

      clean_close

      write_pipe.puts "<EOF>"

      Process.wait
    end

    def execute(pipe = nil, options = {})
      options = {:ide_disk => false}.merge(options)

      @log.debug "Preparing guestfs..."

      @guestfs = pipe.nil? ? Guestfs::create : Guestfs::create.redirect(pipe)

      # https://bugzilla.redhat.com/show_bug.cgi?id=502058
      @guestfs.set_append("noapic")

      @log.trace "Setting debug + trace..."
      @guestfs.set_verbose(1)
      @guestfs.set_trace(1)

      @log.trace "Enabling SElinux support in guestfs..."
      @guestfs.set_selinux(1)

      unless hw_virtualization_available?
        # This wrapper is required especially for EC2 where running qemu-kvm crashes libguestfs
        qemu_wrapper = (RbConfig::CONFIG['host_cpu'].eql?('x86_64') ? "/usr/bin/qemu-system-x86_64" : "/usr/bin/qemu")

        if File.exists?(qemu_wrapper)
          @log.trace "Setting QEMU wrapper to #{qemu_wrapper}..."
          @guestfs.set_qemu(qemu_wrapper)
          @log.trace "QEMU wrapper set."
        end
      end

      @log.trace "Adding drive '#{@raw_disk}'..."
      if options[:ide_disk]
        @guestfs.add_drive_with_if(@raw_disk, 'ide')
      else
        @guestfs.add_drive(@raw_disk)
      end
      @log.trace "Drive added."

      if @guestfs.respond_to?('set_network')
        @log.debug "Enabling networking for GuestFS..."
        @guestfs.set_network(1)
      end

      @log.debug "Launching guestfs..."
      @guestfs.launch

      case @guestfs.list_partitions.size
        when 0
          mount_partition(@guestfs.list_devices.first, '/')
        when 1
          mount_partition(@guestfs.list_partitions.first, '/')
        else
          mount_partitions
      end

      load_selinux_policy

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

      @guestfs.sh("/usr/sbin/load_policy") if !selinux.nil? and !selinux.eql?('disabled')
      @guestfs.aug_close

      @log.trace "SElinux policy loaded."
    end

    def clean_close
      @log.trace "Closing guestfs..."

      @guestfs.sync
      @guestfs.umount_all
      @guestfs.close

      @log.trace "Guestfs closed."
    end

    def mount_partition(part, mount_point)
      @log.trace "Mounting #{part} partition to #{mount_point}..."
      @guestfs.mount_options("", part, mount_point)
      @log.trace "Partition mounted."
    end

    def mount_partitions
      root_partition = nil

      @guestfs.list_partitions.each do |partition|
        mount_partition(partition, '/')

        # TODO: use this http://libguestfs.org/guestfs.3.html#guestfs_vfs_label
        if @guestfs.exists('/sbin/e2label') != 0
          root_partition = partition
          break
        end
        @guestfs.umount(partition)
      end

      raise "No root partition found for '#{File.basename(@raw_disk)}' disk!" if root_partition.nil?

      @guestfs.list_partitions.each do |partition|
        next if partition == root_partition
        mount_partition(partition, @guestfs.sh("/sbin/e2label #{partition}").strip.chomp.gsub('_', ''))
      end
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
