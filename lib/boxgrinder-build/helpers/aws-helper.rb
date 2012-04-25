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

require 'aws-sdk'

module BoxGrinder
  class AWSHelper
    #Setting value of a key to nil in opts_defaults forces non-nil value of key in opts_in
    def parse_opts(opts_in, opts_defaults)
      diff_id = opts_in.keys - opts_defaults.keys
      raise ArgumentError, "Unrecognised argument(s): #{diff_id.join(", ")}" if diff_id.any?

      (opts_in.keys & opts_defaults.keys).each do |k|
        raise ArgumentError, "Argument #{k.to_s} must not be nil" if opts_defaults[k] == nil and opts_in[k] == nil
      end

      (opts_defaults.keys - opts_in.keys).each do |k|
        raise ArgumentError, "Argument #{k.to_s} must not be nil" if opts_defaults[k] == nil
        opts_in.merge!(k => opts_defaults[k])
      end
      opts_in
    end

    def wait_with_timeout(cycle_seconds, timeout_seconds)
      Timeout::timeout(timeout_seconds) do
        while not yield
          sleep cycle_seconds
        end
      end
    end
    
    def self.block_device_mappings_validator(key, map, value)
      split_mappings = value.split('&') # /dev/xvdb=ephemeral0&/dev/xvdc=ephemeral1 

      split_mappings.each do |s_pair|
        name, blockdevice = s_pair.split('=') # /dev/xvdb=ephemeral0
        
        if name.nil? || blockdevice.nil? 
          raise PluginValidationError, 
          "Invalid device mapping: '#{s_pair}' in '#{split_mappings.join(', ')}'"
        else
          name.sub!(/xvd/, 'sd')
        end
        
        bd_keys = [:snapshot_id, :volume_size, :delete_on_termination]
        bd_values = blockdevice.split(':').map { |x| x.empty? ? nil : x }
        
        if bd_values.one? # '/dev/sdb' => 'ephemeral0'
          map.merge!(name => bd_values.first)
        else # '/dev/sdb' => { :snapshot_id => 'snap-123', ... }
          map.merge!(name => Hash[bd_keys.zip(bd_values)])
        end
      end
      map
    end
  end
end
