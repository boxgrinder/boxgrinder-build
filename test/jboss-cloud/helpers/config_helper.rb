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

class ConfigHelper
  def self.generate_config( dir_src = "../../../src", dir_appliances = "../../../appliances" )
    JBossCloud::Config.new("JBoss-Cloud", "1.0.0", nil, "/tmp/dir_rpms_cache", "/tmp/dir_src_cache" , "/tmp/dir_root" , "topdir" , "/tmp/dir_build" , "/tmp/dir_specs" , dir_appliances , dir_src )
  end
  
  def self.generate_appliance_config
    appliance_config = JBossCloud::ApplianceConfig.new("valid-appliance", "i386", "fedora", "10")
    
    appliance_config.disk_size = 2
    appliance_config.summary = "this is a summary"
    appliance_config.network_name = "NAT"
    appliance_config.vcpu = "1"
    appliance_config.mem_size = "1024"
    appliance_config.appliances = [ appliance_config.name ]
    
    appliance_config
  end
  
end