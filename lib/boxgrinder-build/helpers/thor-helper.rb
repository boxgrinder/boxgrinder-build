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

module BoxGrinder
  class ThorHelper < Thor
    class << self
      def help(shell)
        boxgrinder_header(shell)
        super(shell)
      end

      def task_help(shell, task_name)
        boxgrinder_header(shell)

        examples = {
            "$ boxgrinder build jeos.appl" => "# Build KVM image for jeos.appl",
            "$ boxgrinder build jeos.appl -f" => "# Build KVM image for jeos.appl with removing previous build for this image",
            "$ boxgrinder build jeos.appl -p ec2 -d ami" => "# Build and register AMI for jeos.appl",
            "$ boxgrinder build jeos.appl -p vmware -d local" => "# Build VMware image for jeos.appl and deliver it to local directory"
        }.sort { |a, b| a[0] <=> b[0] }

        shell.say "Examples:"
        shell.print_table(examples, :ident => 2, :truncate => true)
        shell.say

        super(shell, task_name)
      end

      def boxgrinder_header(shell)
        shell.say
        shell.say "BoxGrinder Build:"
        shell.say "  A tool for building VM images from simple definition files."
        shell.say
        shell.say "Documentation:"
        shell.say "  http://community.jboss.org/docs/DOC-14358"
        shell.say
      end
    end
  end
end