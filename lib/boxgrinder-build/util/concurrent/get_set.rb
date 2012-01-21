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

require 'thread'

class GetSet
  def initialize(initial_state=false)
    @val = initial_state
    @mutex = Mutex.new
  end

  # Atomic get-and-set.
  #
  # When used with a block, the existing value is provided as
  # an argument to the block. The block's return value sets the
  # object's value state.
  #
  # When used without a block; if a nil +set_val+ parameter is
  # provided the existing state is returned. Else the object
  # value state is set to +set_val+
  def get_set(set_val=nil, &blk)
    @mutex.synchronize do
      if block_given?
        @val = blk.call(@val)
      else
        @val = set_val unless set_val.nil?
      end
      @val
    end
  end
end
