#!/usr/bin/env ruby 

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

require 'test/unit'
require 'jboss-cloud/validator/appliance-dependency-validator'

module JBossCloud
  class ApplianceDependencyValidatorTest < Test::Unit::TestCase
    def setup
      @options = { :log => LogMock.new, :exec_helper => ExecHelperMock.new }
      @validator = ApplianceDependencyValidator.new( ConfigHelper.generate_config, ConfigHelper.generate_appliance_config, @options )
    end

    def test_cached_repomdxml
      options = { :log => LogMock.new, :exec_helper => ExecHelperMock.new( "Not using downloaded repomd.xml because it is older than what we have:
  Current   : Sat Jul 11 04:44:02 2009
  Downloaded: Fri Jul  3 20:41:01 2009
jboss-tools-jboss-as5-0:5.1.0.GA-1.fc11.noarch
java-1.6.0-openjdk-devel-1:1.6.0.0-22.b16.fc11.x86_64
jboss-tools-0:3.1.0.M2-1.fc11.x86_64
jboss-tools-wallpapers-0:1.0.0-1.fc11.noarch
jboss-tools-environment-0:1.0.0.Beta6-1.fc11.noarch
jboss-tools-jboss-as4-0:4.2.3.GA-1.fc11.noarch
jboss-tools-stick-0:1.0.0.Beta6-1.noarch
jboss-tools-eclipse-0:3.5-1.fc11.x86_64
firefox-0:3.5-1.fc11.x86_64

" ) }
      validator = ApplianceDependencyValidator.new( ConfigHelper.generate_config, ConfigHelper.generate_appliance_config, options )

      invalid_names =  validator.invalid_names( "doesnt_matter", [ "invalid-package" ] )

      assert_equal( invalid_names.size, 1 )
      assert_equal( invalid_names[0], "invalid-package" )
    end
  end
end