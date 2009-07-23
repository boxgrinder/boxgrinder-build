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

module JBossCloud
  class GuestFSHelper
    def initialize( raw_disk )
      @raw_disk = raw_disk

      @log = LOG

      launch
    end

    attr_reader :guestfs

    def launch
      @log.debug "Preparing guestfs..."
      @guestfs = Guestfs::create

      # see: https://bugzilla.redhat.com/show_bug.cgi?id=502058
      @guestfs.set_append( "noapic" )


      # workaround for latest qemu
      # It'll only work if qemu-stable package is installed. It is installed by default on meta-appliance
      qemu_wrapper = "/usr/share/qemu-stable/bin/qemu.wrapper"

      if File.exists?( qemu_wrapper )
        @guestfs.set_qemu( qemu_wrapper )
      end

      @log.debug "Adding drive '#{@raw_disk}'..."
      @guestfs.add_drive( @raw_disk )
      @log.debug "Drive added."

      @log.debug "Launching guestfs..."
      @guestfs.launch
      @log.debug "Waiting for guestfs..."
      @guestfs.wait_ready
      @log.debug "Guestfs launched."

      if @guestfs.list_partitions.size > 0
        partition_to_mount = "/dev/sda1"
      else
        partition_to_mount = "/dev/sda"
      end

      @log.debug "Mounting root partition..."
      @guestfs.mount( partition_to_mount, "/" )
      @log.debug "Root partition mounted."

      # TODO is this really needed?
      @log.debug "Uploading '/etc/resolv.conf'..."
      @guestfs.upload( "/etc/resolv.conf",  "/etc/resolv.conf" )
      @log.debug "'/etc/resolv.conf' uploaded."

      @log.debug "Guestfs launched."
    end
  end
end