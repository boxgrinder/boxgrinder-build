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
  class ScientificLinuxPlugin < RHELPlugin

    SL_REPOS = {
     "5" => {
       "base" => {
         "baseurl" => "http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/SL/"
        },
       "security" => {
         "baseurl" => "http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/updates/security/"
        }
      },
     "6" => {
       "base" => {
         "baseurl" => "http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/os/"
        },
       "security" => {
         "baseurl" => "http://ftp.scientificlinux.org/linux/scientific/#OS_VERSION#x/#BASE_ARCH#/updates/security/"
        }
      }
    }

    def after_init
      super
      register_supported_os('sl', ['5', '6'])
    end

    def execute(appliance_definition_file)
      build_rhel(appliance_definition_file, SL_REPOS)
    end

  end
end

plugin :class => BoxGrinder::ScientificLinuxPlugin, :type => :os, :name => :sl, :full_name  => "Scientific Linux", :versions   => ["5", "6"]

