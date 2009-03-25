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
require 'jboss-cloud/validator/appliance-validator'

class ApplianceValidatorTest < Test::Unit::TestCase
  def setup
    @appliances_dir = "../../../appliances"
  end
  
  # def teardown
  # end
  
  def test_appliances_for_validity
    Dir[ "#{@appliances_dir}/*/*.appl" ].each do |appliance_def|
      assert_not_nil JBossCloud::ApplianceValidator.new( @appliances_dir, appliance_def ), "Validator shouldn't be nil!"
    end if File.exists?( @appliances_dir ) # for stand-alone jboss-cloud-support testing
  end
  
  def test_nil_appliances_dir
    assert_raise JBossCloud::ApplianceValidationError do
      JBossCloud::ApplianceValidator.new( nil, nil )
    end
  end
  
  def test_doesnt_exists_appliances_dir
    assert_raise JBossCloud::ApplianceValidationError do
      JBossCloud::ApplianceValidator.new( "bled/sd/sd", nil )
    end
  end
  
  def test_init_and_raise_validation_error_if_file_is_nil
    assert_raise JBossCloud::ApplianceValidationError do
      JBossCloud::ApplianceValidator.new( "src/appliances", nil )
    end
  end
  
  def test_init_and_raise_validation_error_if_file_doesnt_exists
    assert_raise JBossCloud::ApplianceValidationError do
      JBossCloud::ApplianceValidator.new( "src/appliances", "strange/path.appl" )
    end
  end
  
  def test_appliance_without_summary
    validator = JBossCloud::ApplianceValidator.new( "src/appliances", "src/appliances/without-summary-appliance/without-summary-appliance.appl" )
    assert_raise JBossCloud::ApplianceValidationError do
      validator.validate
    end
  end
  
  def test_multiappliance_without_dependent_appliance
    validator = JBossCloud::ApplianceValidator.new( "src/appliances", "src/appliances/without-dependent-appliances-appliance/without-dependent-appliances-appliance.appl" )
    assert_not_nil validator , "Validator shouldn't be nil!"
    
    assert_raise JBossCloud::ApplianceValidationError do
      validator.validate
    end
  end
  
  def test_valid_data
    validator = JBossCloud::ApplianceValidator.new( "src/appliances", "src/appliances/valid-appliance/valid-appliance.appl" )
    assert_not_nil validator , "Validator shouldn't be nil!"
    validator.validate
  end
end
