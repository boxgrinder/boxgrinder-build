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

require 'boxgrinder-build/plugins/os/rhel/rhel-plugin'

module BoxGrinder
  class CentOSPlugin < RHELPlugin

    def after_init
      super
      register_supported_os('centos', ['5', '6'])
    end

    def execute(appliance_definition_file)
      repos = {}

     @plugin_info[:versions].each do |version|
      repos[version] = {
          "base" => {
              "mirrorlist" => "http://mirrorlist.centos.org/?release=#OS_VERSION#&arch=#BASE_ARCH#&repo=os"
          },
          "updates" => {
              "mirrorlist" => "http://mirrorlist.centos.org/?release=#OS_VERSION#&arch=#BASE_ARCH#&repo=updates"
          }
        }
      end

      build_rhel(appliance_definition_file, repos)
    end
  end
end

plugin :class => BoxGrinder::CentOSPlugin, :type => :os, :name => :centos, :full_name  => "CentOS", :versions   => ["5", "6"]
