#
# Copyright 2012 Red Hat, Inc.
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

require 'tmpdir'

module BoxGrinder
  class UserSwitcher
  
    def UserSwitcher.change_user(u, g, &blk)
      prev_u, prev_g = Process.uid, Process.gid
      libguestfs_cache_workaround
      set_user(u, g) 
      blk.call
      set_user(prev_u, prev_g)
    end

    private

    # Working around bugs.... we can rely on the saved id to be able
    # to sneak back to the previous user later.
    def UserSwitcher.set_user(u, g)
      return if Process.uid == u && Process.gid == g
      # If already set to the given value
      Process.egid, Process.gid = g, g
      Process.euid, Process.uid = u, u
    end

    # Workaround
    def UserSwitcher.libguestfs_cache_workaround
      FileUtils.rm_rf("#{ENV['TMPDIR']||Dir.tmpdir||'/tmp'}/.guestfs-#{Process.euid}")
    end
  end
end
