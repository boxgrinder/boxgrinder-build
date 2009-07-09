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
require 'jboss-cloud/test-helpers/config-helper'

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

  def prepare_valid_kickstart
    params = OpenStruct.new
    params.dir_appliances = "src/appliances"

    JBossCloud::ApplianceKickstart.new( ConfigHelper.generate_config( params ), ConfigHelper.generate_appliance_config )
  end

  def prepare_valid_kickstart_gnome
    params = OpenStruct.new
    params.dir_appliances = "src/appliances"

    JBossCloud::ApplianceKickstart.new( ConfigHelper.generate_config( params ), ConfigHelper.generate_appliance_config_gnome )
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

    assert_equal( definition['repos'][0], "repo --name=postgresql --baseurl=http://yum.pgsqlrpms.org/8.3/fedora/fedora-11-#{@current_arch}/" )
    assert_equal( definition['repos'][1], "repo --name=fedora-rawhide-base --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=#{@current_arch}" )

  end

  def test_definitions_with_fedora_11
    definition = prepare_valid_kickstart.build_definition

    common_definition_test( definition )

    assert_operator(definition['local_repos'].size, :==, 2)

    assert_equal( definition['local_repos'][0], "repo --name=jboss-cloud --cost=10 --baseurl=file:///tmp/dir_root/topdir/fedora/11/RPMS/noarch" )
    assert_equal( definition['local_repos'][1], "repo --name=jboss-cloud-#{@current_arch} --cost=10 --baseurl=file:///tmp/dir_root/topdir/fedora/11/RPMS/#{@current_arch}" )

    assert_operator(definition['repos'].size, :==, 3)

    assert_equal( definition['repos'][0], "repo --name=postgresql --baseurl=http://yum.pgsqlrpms.org/8.3/fedora/fedora-11-#{(-1.size) == 8 ? "x86_64" : "i386"}/" )
    assert_equal( definition['repos'][1], "repo --name=fedora-11-base --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-11&arch=#{@current_arch}" )
    assert_equal( definition['repos'][2], "repo --name=fedora-11-updates --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f11&arch=#{@current_arch}" )
  end

  def test_build_definition_packages
    definition = prepare_valid_kickstart.build_definition

    assert_equal definition['packages'].size, 2
    assert_equal definition['packages'], [ 'httpd', 'mod_cluster' ]
  end

  def test_without_x
    definition = prepare_valid_kickstart.build_definition

    assert_equal definition['graphical'], false
  end

  def test_with_gnome
    definition = prepare_valid_kickstart_gnome.build_definition

    assert_equal definition['graphical'], true
  end

  def test_disk_size
    definition = prepare_valid_kickstart.build_definition

    assert_equal definition['disk_size'], 2048
  end

  def test_root_password
    definition = prepare_valid_kickstart.build_definition

    assert_equal definition['root_password'], "oddthesis"
  end

  def test_filesystem_type
    definition = prepare_valid_kickstart.build_definition

    assert_equal definition['fstype'], "ext3"
  end


end