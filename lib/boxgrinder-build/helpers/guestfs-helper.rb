# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
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

require 'guestfs'
require 'logger'

module Guestfs
  class Guestfs
    alias_method :sh_original, :sh

    def sh( command )
      @log.trace "Executing '#{command}' command using GuestFS"

      begin
        output = sh_original( command )
        @log.trace "Command return:\r\n+++++\r\n#{output}+++++" unless output.strip.length == 0
      rescue => e
        @log.error e.backtrace.join($/)
        @log.error "Error occurred while executing above command. Appliance may not work properly."
      end

      output
    end
  end
end

module BoxGrinder
  class GuestFSHelper
    def initialize( raw_disk, options = {} )
      @raw_disk = raw_disk
      @log      = options[:log] || Logger.new(STDOUT)

      @partitions = {}

      run
    end

    attr_reader :guestfs

    def run
      @log.debug "Preparing guestfs..."
      @guestfs = Guestfs::create
      @guestfs.instance_variable_set( :@log, @log )

      # TODO remove this, https://bugzilla.redhat.com/show_bug.cgi?id=502058
      @guestfs.set_append( "noapic" )

      # workaround for latest qemu
      # It'll only work if qemu-stable package is installed. It is installed by default on meta-appliance
      # TODO wait for stable qemu and remove this
      qemu_wrapper = "/usr/share/qemu-stable/bin/qemu.wrapper"

      if File.exists?( qemu_wrapper )
        @guestfs.set_qemu( qemu_wrapper )
      end

      @log.trace "Adding drive '#{@raw_disk}'..."
      @guestfs.add_drive( @raw_disk )
      @log.trace "Drive added."

      @log.debug "Launching guestfs..."
      @guestfs.launch

      case @guestfs.list_partitions.size
        when 0
          mount_partition( @guestfs.list_devices.first, '/' )
        when 1
          mount_partition( @guestfs.list_partitions.first, '/' )
        else
          mount_partitions
      end

      @log.trace "Guestfs launched."
    end

    def clean_close
      @log.trace "Closing guestfs..."

      @guestfs.sync
      @guestfs.umount_all
      @guestfs.close

      @log.trace "Guestfs closed."
    end

    def mount_partition( part, mount_point )
      @log.trace "Mounting #{part} partition to #{mount_point}..."
      @guestfs.mount_options( "", part, mount_point )
      @log.trace "Partition mounted."
    end

    # TODO this is shitty, I know... https://bugzilla.redhat.com/show_bug.cgi?id=507188
    def rebuild_rpm_database
      @log.debug "Cleaning RPM database..."
      @guestfs.sh( "rm -f /var/lib/rpm/__db.*" )
      @guestfs.sh( "rpm --rebuilddb" )
      @log.debug "Cleaning RPM database finished."
    end

    def mount_partitions
      root_partition = nil

      @guestfs.list_partitions.each do |partition|
        mount_partition( partition, '/' )
        if @guestfs.exists( '/sbin/e2label' ) != 0
          root_partition = partition
          break
        end
        @guestfs.umount( partition )
      end

      raise "No root partition found for '#{File.basename( @raw_disk )}' disk!" if root_partition.nil?

      @guestfs.list_partitions.each do |partition|
        next if partition == root_partition
        mount_partition( partition, @guestfs.sh( "/sbin/e2label #{partition}" ).chomp.strip )
      end
    end
  end
end