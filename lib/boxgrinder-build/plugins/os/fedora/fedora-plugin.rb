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

require 'boxgrinder-build/plugins/os/rpm-based/rpm-based-os-plugin'

module BoxGrinder
  class FedoraPlugin < RPMBasedOSPlugin
    def after_init
      super
      register_supported_os('fedora', ["13", "14", "rawhide"])
    end

    def execute(appliance_definition_file)
      normalize_packages(@appliance_config.packages)

      @repos = {}

      @plugin_info[:versions].each do |version|
        if version.match(/\d+/)
          @repos[version] = {
              "base" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-#{version}&arch=#BASE_ARCH#"},
              "updates" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f#{version}&arch=#BASE_ARCH#"}
          }
        else
          @repos[version] = {"base" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=#{version}&arch=#BASE_ARCH#"}}
        end
      end

      build_with_appliance_creator(appliance_definition_file, @repos)
    end

    def normalize_packages(packages)
      # https://issues.jboss.org/browse/BGBUILD-89
      packages << '@core'
      packages << "system-config-firewall-base"
      packages << "dhclient"
      
      # kernel_PAE for 32 bit, kernel for 64 bit
      packages.delete('kernel')
      packages.delete('kernel-PAE')
      packages << (@appliance_config.is64bit? ? "kernel" : "kernel-PAE")
    end
  end
end
