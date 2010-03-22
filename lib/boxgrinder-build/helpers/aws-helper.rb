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

require 'AWS'
require 'aws/s3'
require 'boxgrinder-core/defaults'
require 'boxgrinder-build/validators/aws-validator'

module BoxGrinder
  class AWSHelper
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config

      aws_validator = AWSValidator.new( @config )
      aws_validator.validate_aws_config( @config.data['aws'] )

      @aws_data = @config.data['aws']

      # remove dashes from account number
      @aws_data['account_number'] = @aws_data['account_number'].to_s.gsub(/-/, '')

      @ec2        = AWS::EC2::Base.new(:access_key_id => @aws_data['access_key'], :secret_access_key => @aws_data['secret_access_key'])
      @s3         = AWS::S3::Base.establish_connection!(:access_key_id => @aws_data['access_key'], :secret_access_key => @aws_data['secret_access_key'] )
    end

    attr_reader :aws_data
    attr_reader :ec2
    attr_reader :s3

    def bucket_key( appliance_name )
      "#{@aws_data['bucket_name']}/#{@config.version_with_release}/#{@appliance_config.hardware.arch}/#{appliance_name}"
    end

    def bucket_manifest_key( appliance_name )
      "#{bucket_key( appliance_name )}/#{appliance_name}.ec2.manifest.xml"
    end

    def appliance_is_registered?( appliance_name )
      !ami_info( appliance_name ).nil?
    end

    def ami_info( appliance_name )
      ami_info = nil

      images = @ec2.describe_images( :owner_id => @aws_data['account_number'] ).imagesSet

      return nil if images.nil?

      for image in images.item do
        ami_info = image if (image.imageLocation.eql?( bucket_manifest_key( appliance_name ) ))
      end

      ami_info
    end
  end
end