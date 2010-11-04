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
require 'guestfs'
require 'logger'
require 'open-uri'

module BoxGrinder
  class SilencerProxy
    def initialize(o, destination)
      @o            = o
      @destination  = destination
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
        puts "Error occurred while executing above command. Appliance may not work properly."
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
      @log      = options[:log] || Logger.new(STDOUT)

      @partitions = {}
    end

    attr_reader :guestfs

    def hw_virtualization_available?
      @log.trace "Checking if HW virtualization is available..."

      begin
        open('http://169.254.169.254/1.0/meta-data/local-ipv4')
        ec2 = true
      rescue
        ec2 = false
      end

      if `cat /proc/cpuinfo | grep flags | grep vmx | wc -l`.chomp.strip.to_i > 0 and !ec2
        @log.trace "HW acceleration available."
        return true
      end

      @log.trace "HW acceleration not available."

      false
    end

    def customize
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

      helper = execute(write_pipe)

      yield @guestfs, helper

      clean_close

      write_pipe.puts "<EOF>"

      Process.wait
    end

    def execute(pipe = nil)
      @log.debug "Preparing guestfs..."

      @guestfs = pipe.nil? ? Guestfs::create : Guestfs::create.redirect(pipe)

      # https://bugzilla.redhat.com/show_bug.cgi?id=502058
      @guestfs.set_append("noapic")

      @log.trace "Setting debug + trace..."
      @guestfs.set_verbose(1)
      @guestfs.set_trace(1)

      unless hw_virtualization_available?
        qemu_wrapper =  (`uname -m`.chomp.strip.eql?('x86_64') ? "/usr/bin/qemu-system-x86_64" : "/usr/bin/qemu")
        @log.trace "Setting QEMU wrapper to #{qemu_wrapper}..."
        @guestfs.set_qemu(qemu_wrapper) if File.exists?(qemu_wrapper)
        @log.trace "QEMU wrapper set."
      end

      @log.trace "Adding drive '#{@raw_disk}'..."
      @guestfs.add_drive(@raw_disk)
      @log.trace "Drive added."

      @log.debug "Enabling networking for GuestFS..."
      @guestfs.set_network(1)

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

      @log.trace "Guestfs launched."

      self
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

    # TODO this is shitty, I know... https://bugzilla.redhat.com/show_bug.cgi?id=507188
    def rebuild_rpm_database
      @log.debug "Cleaning RPM database..."
      @guestfs.sh("rm -f /var/lib/rpm/__db.*")
      @guestfs.sh("rpm --rebuilddb")
      @log.debug "Cleaning RPM database finished."
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
        mount_partition(partition, @guestfs.sh("/sbin/e2label #{partition}").chomp.strip)
      end
    end

    def sh(cmd, options = {})
      arch = options[:arch] || `uname -m`.chomp.strip

      @log.debug "Executing #{cmd}"
      @guestfs.sh("setarch #{arch} << SETARCH_EOF\n#{cmd.gsub('$', '\$')}\nSETARCH_EOF\n")
    end

    def augeas(&block)
      AugeasHelper.new(@guestfs, self, :log => @log).edit(&block)
    end
  end
end
