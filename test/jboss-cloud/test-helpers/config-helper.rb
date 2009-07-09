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

require 'ostruct'

class ConfigHelper
  def self.generate_config( params = OpenStruct.new )

    dir = OpenStruct.new

    dir.rpms_cache   = params.dir_rpms_cache || "/tmp/dir_rpms_cache"
    dir.root         = params.dir_root       || "/tmp/dir_root"
    dir.top          = params.dir_top        || "topdir"
    dir.build        = params.dir_build      || "/tmp/dir_build"
    dir.specs        = params.dir_specs      || "/tmp/dir_specs"
    dir.appliances   = params.dir_appliances || "../../../appliances"
    dir.src          = params.dir_src        || "../../../src"

    config = JBossCloud::Config.new( params.name || "JBoss-Cloud", params.version || "1.0.0", params.release, dir, params.config_file.nil? ? "" : "src/#{params.config_file}" )

    # files
    config.files.base_vmdk  = params.base_vmdk      || "../../../src/base.vmdk"
    config.files.base_vmx   = params.base_vmx       || "../../../src/base.vmx"

    config
  end

  def self.generate_appliance_config( os_version = "11" )
    appliance_config = JBossCloud::ApplianceConfig.new("valid-appliance", (-1.size) == 8 ? "x86_64" : "i386", "fedora", os_version)

    appliance_config.disk_size = 2
    appliance_config.summary = "this is a summary"
    appliance_config.network_name = "NAT"
    appliance_config.vcpu = "1"
    appliance_config.mem_size = "1024"
    appliance_config.appliances = [ appliance_config.name ]

    appliance_config
  end

  def self.generate_appliance_config_gnome( os_version = "11" )
    appliance_config = JBossCloud::ApplianceConfig.new("valid-appliance-gnome", (-1.size) == 8 ? "x86_64" : "i386", "fedora", os_version)

    appliance_config.disk_size = 2
    appliance_config.summary = "this is a summary"
    appliance_config.network_name = "NAT"
    appliance_config.vcpu = "1"
    appliance_config.mem_size = "1024"
    appliance_config.appliances = [ appliance_config.name ]

    appliance_config
  end

end