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
require 'jboss-cloud/helpers/config-helper'

module JBossCloud
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
      @params.config_file = "configs/aws_no_path_cert"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Please specify path to cert in aws section in configuration file \(src\/configs\/aws_no_path_cert\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
    end

    def test_validate_file_cert
      @params.config_file = "configs/aws_no_file_cert"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Certificate file '\/this\/is\/a\/path' specified in configuration file \(src\/configs\/aws_no_file_cert\) doesn't exists\. Please check your path\./, exception.message
    end

    def test_validate_path_key
      @params.config_file = "configs/aws_no_path_key"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Please specify path to private key in aws section in configuration file \(src\/configs\/aws_no_path_key\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
    end

    def test_validate_file_key
      @params.config_file = "configs/aws_no_file_key"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Private key file '\/this\/is\/a\/path' specified in aws section in configuration file \(src\/configs\/aws_no_file_key\) doesn't exists\. Please check your path\./, exception.message
    end

    def test_validate_account_number
      @params.config_file = "configs/aws_no_account_number"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Please specify account number in aws section in configuration file \(src\/configs\/aws_no_account_number\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
    end

    def test_validate_bucket_name
      @params.config_file = "configs/aws_no_bucket_name"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Please specify bucket name in aws section in configuration file \(src\/configs\/aws_no_bucket_name\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
    end

    def test_validate_access_key
      @params.config_file = "configs/aws_no_access_key"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Please specify access key in aws section in configuration file \(src\/configs\/aws_no_access_key\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
    end

    def test_validate_secret_access_key
      @params.config_file = "configs/aws_no_secret_access_key"

      exception = assert_raise JBossCloud::ValidationError do
        JBossCloud::AWSSupport.new( ConfigHelper.generate_config( @params ) )
      end
      assert_match /Please specify secret access key in aws section in configuration file \(src\/configs\/aws_no_secret_access_key\)\. See http:\/\/oddthesis\.org\/theses\/jboss-cloud\/projects\/jboss-cloud-support\/pages\/ec2-configuration-file for more info\./, exception.message
    end

  end
end