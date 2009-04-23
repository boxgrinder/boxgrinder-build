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
require 'jboss-cloud/aws/aws-support'
require 'jboss-cloud/helpers/config_helper'

class AWSSupportTest < Test::Unit::TestCase

  def setup
    @params = OpenStruct.new
  end

  def test_validate_config_without_aws_section
    @params.config_file = "configs/empty"

    exception = assert_raise JBossCloud::ValidationError do
      JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
    end
    assert_match /Please specify aws section in configuration file \(src\/configs\/empty\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
  end

  def test_validate_path_cert
    @params.config_file = "configs/aws_section"

    exception = assert_raise JBossCloud::ValidationError do
      JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
    end
    assert_match /Please specify path to cert in aws section in configuration file \(src\/configs\/aws_section\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
  end

end