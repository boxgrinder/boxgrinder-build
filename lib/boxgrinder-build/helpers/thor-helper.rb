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

require 'thor'

class Thor
  module CoreExt
    class HashWithIndifferentAccess < ::Hash
      def initialize(hash={})
        super()
        hash.each do |key, value|
          self[convert_key(key)] = value
        end

        to_boolean(self)
      end

      def to_boolean(h)
        h.each do |k, v|
          if v.is_a?(Hash)
            to_boolean(v)
            next
          end

          next unless v.is_a?(String)

          case v
            when /^true$/i then
              h[k] = true
            when /^false$/i then
              h[k] = false
          end
        end
      end
    end
  end
end

module BoxGrinder
  class ThorHelper < Thor
    class << self
      def help(shell)
        boxgrinder_header(shell)
        super(shell)
      end

      def task_help(shell, task_name)
        boxgrinder_header(shell)

        help_method = "#{task_name}_help".to_sym
        send(help_method, shell) if respond_to?(help_method) and method(help_method).arity == 1
        super(shell, task_name)

        shell.say
      end

      def boxgrinder_header(shell)
        shell.say
        shell.say "BoxGrinder Build:"
        shell.say "  A tool for building VM images from simple definition files."
        shell.say
        shell.say "Homepage:"
        shell.say "  http://boxgrinder.org/"
        shell.say
        shell.say "Documentation:"
        shell.say "  http://boxgrinder.org/tutorials/"
        shell.say
      end
    end
  end
end