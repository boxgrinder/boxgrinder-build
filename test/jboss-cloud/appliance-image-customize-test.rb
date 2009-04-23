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
require 'jboss-cloud/appliance-image-customize'
require 'jboss-cloud/validator/errors'

class ApplianceImageCustomizeTest < Test::Unit::TestCase
  def setup
    @appliance_customize = JBossCloud::ApplianceImageCustomize.new( ConfigHelper.generate_config, ConfigHelper.generate_appliance_config )
  end
  
  def test_empty_package_arrays
    assert_nothing_raised do 
      @appliance_customize.customize( "/no/raw/file.raw" )
    end
  end
  
  def test_raw_file_not_valid
    exception = assert_raise JBossCloud::ValidationError do
      @appliance_customize.customize( "/no/raw/file.raw", { :yum_local => [ "i386/dkms-open-vm-tools-2009.03.18-154848.i386.rpm", "noarch/vm2-support-1.0.0.Beta1-1.noarch.rpm" ] } )  
    end
    assert_match /Raw file '\/no\/raw\/file.raw' doesn't exists, please specify valid raw file/, exception.message
  end
  
  
  
end