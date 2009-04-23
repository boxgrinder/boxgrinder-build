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
require "jboss-cloud/helpers/config_helper"

require 'jboss-cloud/defaults'
require 'jboss-cloud/appliance-kickstart'

class ApplianceKickstartTest < Test::Unit::TestCase

  def setup
    @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
  end

  def common_definition_test( definition )
    # kickstart disk size is in MB (not GB!)
    assert_equal( definition['disk_size'], 2 * 1024 )
    assert_equal( definition['appl_name'], "valid-appliance" )
    assert_equal( definition['arch'], @current_arch)
    assert_equal( definition['appliance_names'], [ "valid-appliance" ] )
  end
  
  def test_definitions_with_rawhide
    
    params = OpenStruct.new
    params.dir_appliances = "src/appliances"
    
    definition = JBossCloud::ApplianceKickstart.new( ConfigHelper.generate_config( params ), ConfigHelper.generate_appliance_config( "rawhide" ) ).build_definition
    
    common_definition_test( definition )
    
    assert_operator(definition['local_repos'].size, :==, 2)
    
    assert_equal( definition['local_repos'][0], "repo --name=jboss-cloud --cost=10 --baseurl=file:///tmp/dir_root/topdir/fedora/rawhide/RPMS/noarch" )
    assert_equal( definition['local_repos'][1], "repo --name=jboss-cloud-#{@current_arch} --cost=10 --baseurl=file:///tmp/dir_root/topdir/fedora/rawhide/RPMS/#{@current_arch}" )
    
    assert_operator(definition['repos'].size, :==, 2)
    
    assert_equal( definition['repos'][0], "repo --name=postgresql --baseurl=http://yum.pgsqlrpms.org/8.3/fedora/fedora-10-#{@current_arch}/" )
    assert_equal( definition['repos'][1], "repo --name=fedora-rawhide-base --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=#{@current_arch}" )
    
  end
  
  def test_definitions_with_fedora_10
    
    params = OpenStruct.new
    params.dir_appliances = "src/appliances"
    
    definition = JBossCloud::ApplianceKickstart.new( ConfigHelper.generate_config( params ), ConfigHelper.generate_appliance_config ).build_definition
    
    common_definition_test( definition )
    
    assert_operator(definition['local_repos'].size, :==, 2)
    
    assert_equal( definition['local_repos'][0], "repo --name=jboss-cloud --cost=10 --baseurl=file:///tmp/dir_root/topdir/fedora/10/RPMS/noarch" )
    assert_equal( definition['local_repos'][1], "repo --name=jboss-cloud-#{@current_arch} --cost=10 --baseurl=file:///tmp/dir_root/topdir/fedora/10/RPMS/#{@current_arch}" )
    
    assert_operator(definition['repos'].size, :==, 3)
    
    assert_equal( definition['repos'][0], "repo --name=postgresql --baseurl=http://yum.pgsqlrpms.org/8.3/fedora/fedora-10-#{(-1.size) == 8 ? "x86_64" : "i386"}/" )
    assert_equal( definition['repos'][1], "repo --name=fedora-10-base --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-10&arch=#{@current_arch}" )
    assert_equal( definition['repos'][2], "repo --name=fedora-10-updates --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f10&arch=#{@current_arch}" )

    
  end
end