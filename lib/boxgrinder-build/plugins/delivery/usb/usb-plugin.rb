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

require 'boxgrinder-build/plugins/base-plugin'

module BoxGrinder
  class USBPlugin < BasePlugin
    def after_init
      validate_plugin_config(['device' ])
    end

    def execute( type = :usb )
      validate_device

      @log.debug "Using '#{@plugin_config['device']}' as a target device..."
      @exec_helper.execute( "dd if=#{@previous_deliverables.disk} of=#{@plugin_config['device']} bs=1M" )

    end

    def validate_device
      # check if this is USB
      # see if it contains required space
    end

  end
end
