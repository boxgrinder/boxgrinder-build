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

require 'boxgrinder-core/helpers/log-helper'

module BoxGrinder
  class AugeasHelper
    def initialize(guestfs, guestfs_helper, options = {})
      @guestfs        = guestfs
      @guestfs_helper = guestfs_helper
      @log            = options[:log] || LogHelper.new

      @files = {}
    end

    def edit(&block)
      @log.debug "Changing configuration files using augeas..."

      instance_eval &block if block

      if @files.empty?
        @log.debug "No files specified to change, skipping..."
        return
      end

      if @guestfs.debug("help", []).include?('core_pattern')
        @log.trace "Enabling coredump catching for augeas..."
        @guestfs.debug("core_pattern", ["/sysroot/core"])
      end

      @guestfs.aug_init("/", 32)

      unload = []

      @files.keys.each do |file_name|
        unload << ". != '#{file_name}'"
      end

      @guestfs.aug_rm("/augeas/load//incl[#{unload.join(' and ')}]")
      @guestfs.aug_load

      @files.each do |file, changes|
        changes.each do |key, value|

          @guestfs.aug_set("/files#{file}/#{key}", value)
        end
      end

      @guestfs.aug_save
      @guestfs.aug_close

      @log.debug "Augeas changes saved."
    end

    def set(name, key, value)
      unless @guestfs.exists(name) != 0
        @log.debug "File '#{name}' doesn't exists, skipping augeas changes..."
        return
      end

      @files[name] = {} unless @files.has_key?(name)
      @files[name][key] = value
    end
  end
end
