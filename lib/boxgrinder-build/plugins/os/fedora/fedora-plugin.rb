# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
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

require 'boxgrinder-build/plugins/os/base/rpm-based-os-plugin'
require 'boxgrinder-build/plugins/os/base/kickstart'
require 'boxgrinder-build/plugins/os/base/validators/rpm-dependency-validator'

module BoxGrinder
  class FedoraPlugin < RPMBasedOSPlugin

    FEDORA_REPOS = {
            "12" => {
                    "base" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-12&arch=#ARCH#"
                    },
                    "updates" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f12&arch=#ARCH#"
                    }
            },
            "11" => {
                    "base" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-11&arch=#ARCH#"
                    },
                    "updates" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f11&arch=#ARCH#"
                    }
            },
            "rawhide" => {
                    "base" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=#ARCH#"
                    }
            }

    }

    def info
      {
              :name       => :fedora,
              :full_name  => "Fedora",
              :versions   => ["11", "12", "rawhide"]
      }
    end

    def build
      raise "Build cannot be started before the plugin isn't initialized" if @initialized.nil?

      build_with_appliance_creator( FEDORA_REPOS )
    end
  end
end