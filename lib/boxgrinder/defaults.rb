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

require 'boxgrinder/log'
require 'boxgrinder/helpers/exec-helper'
require 'rbconfig'

module BoxGrinder
  LOG = Log.new
  EXEC_HELPER = ExecHelper.new

  # here are global variables
  SUPPORTED_ARCHES = [ "i386", "x86_64" ]
  SUPPORTED_OSES = {
          "fedora" => [ "12", "11", "rawhide" ]
  }

  LATEST_STABLE_RELEASES = {
          "fedora" => "11",
          "rhel" => "5"
  }

  DEVELOPMENT_RELEASES = {
          "fedora" => "rawhide"
  }

  APPLIANCE_DEFAULTS = {
          :os => {
                  :name => "fedora",
                  :version => LATEST_STABLE_RELEASES['fedora'],
                  :password => "boxgrinder"
          },
          :hardware => {
                  :arch => RbConfig::CONFIG['host_cpu'],
                  :partition => 1,
                  :memory => 256,
                  :network => "NAT",
                  :cpus => 1
          }
  }

  SUPPORTED_DESKTOP_TYPES = [ "gnome" ]

  # you can use #ARCH# variable to specify build arch
  REPOS = {
          "fedora" => {
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
  }

  DEFAULT_HELP_TEXT = {
          :general => "See http://oddthesis.org/ for more info."
  }

  DEFAULT_PROJECT_CONFIG = {
          :name => 'BoxGrinder',
          :version => '1.0.0.Beta1',
          :release => 'SNAPSHOT',
          :dir_build => 'build',
          #:topdir            => "#{self.} build/topdir",
          :dir_sources_cache => 'sources-cache',
          :dir_rpms_cache => 'rpms-cache',
          :dir_specs => 'specs',
          :dir_appliances => 'appliances',
          :dir_src => 'src',
          :dir_kickstarts => 'kickstarts'
  }

  AWS_DEFAULTS = {
          :bucket_prefix => "#{DEFAULT_PROJECT_CONFIG[:name].downcase}/#{DEFAULT_PROJECT_CONFIG[:version]}-#{DEFAULT_PROJECT_CONFIG[:release]}",
          :kernel_id => { "i386" => "aki-a71cf9ce", "x86_64" => "aki-b51cf9dc" },
          :ramdisk_id => { "i386" => "ari-a51cf9cc", "x86_64" => "ari-b31cf9da" },
          :kernel_rpm => { "i386" => "http://repo.oddthesis.org/packages/other/kernel-xen-2.6.21.7-2.fc8.i686.rpm", "x86_64" => "http://repo.oddthesis.org/packages/other/kernel-xen-2.6.21.7-2.fc8.x86_64.rpm" }
  }
end