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

class ConfigTest < Test::Unit::TestCase
  
  def setup
    @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
  end
  
  def self.generate_valid_config( release = nil )
    JBossCloud::Config.new("JBoss-Cloud", "1.0.0", release, "/tmp/dir_rpms_cache", "/tmp/dir_src_cache" , "/tmp/dir_root" , "/tmp/dir_top" , "/tmp/dir_build" , "/tmp/dir_specs" , "/tmp/dir_appliances" , "/tmp/dir_src" )
  end
  
  def test_initialize_config
    assert_nothing_raised do
      ConfigTest.generate_valid_config
    end
  end
  
  def test_defaults
    config = ConfigTest.generate_valid_config
    
    assert_equal( config.os_name, "fedora" )
    assert_equal( config.os_version, "10" )
    
    assert_equal( config.build_arch, @current_arch )
  end  
  
  def test_os_path
    config = ConfigTest.generate_valid_config
    
    assert_equal( config.os_path, "fedora/10" )
  end  
  
  def test_build_path
    config = ConfigTest.generate_valid_config
    
    assert_equal( config.build_path, "#{@current_arch}/fedora/10" )
  end  
  
  def test_version_with_relesase_with_release
    config = ConfigTest.generate_valid_config( "1" )
    
    assert_equal( config.version_with_release, "1.0.0-1" )
  end  
  
  def test_version_with_relesase_without_release
    config = ConfigTest.generate_valid_config
    
    assert_equal( config.version_with_release, "1.0.0" )
  end  
  
end
