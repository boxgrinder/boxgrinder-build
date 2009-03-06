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

require "test/unit"
require 'jboss-cloud/config'

class ApplianceConfigTest < Test::Unit::TestCase
  def test_hash_with_empty_appliances_list
    assert_nothing_raised do
      JBossCloud::ApplianceConfig.new("really-good-appliance", "i386", "fedora", "10").hash
    end
  end
  
  def test_simple_name_with_appliance_at_the_end
    appliance_config = JBossCloud::ApplianceConfig.new("really-good-appliance", "i386", "fedora", "10")
    
    assert_equal(appliance_config.simple_name, "really-good")
  end
  
  def test_simple_name_without_appliance_at_the_end
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.simple_name, "really-good")
  end
  
  def test_os_path
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.os_path, "fedora/10")
  end
  
  def test_build_path
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.main_path, "i386/fedora/10")
  end
  
  def test_appliance_path
    appliance_config = JBossCloud::ApplianceConfig.new("really-good", "i386", "fedora", "10")
    
    assert_equal(appliance_config.appliance_path, "appliances/i386/fedora/10/really-good")
  end
end