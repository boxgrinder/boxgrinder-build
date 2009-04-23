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

require 'EC2'
require 'aws/s3'
require 'jboss-cloud/defaults'

module JBossCloud
  class AWSSupport

    def initialize( config )
      @config     = config
      @aws_data   = validate_aws_config
      @ec2        = EC2::Base.new(:access_key_id => @aws_data['access_key'], :secret_access_key => @aws_data['secret_access_key'])
      @s3         = AWS::S3::Base.establish_connection!(:access_key_id => @aws_data['access_key'],  :secret_access_key => @aws_data['secret_access_key'] )
    end

    attr_reader :aws_data
    attr_reader :ec2
    attr_reader :s3

    def bucket_key( appliance_name )
      "#{@aws_data['bucket_name']}/#{@config.aws.bucket_prefix}/#{appliance_name}"
    end

    def bucket_manifest_key( appliance_name )
      "#{bucket_key( appliance_name )}/#{appliance_name}-ec2.img.manifest.xml"
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

    def validate_aws_config
      secure_permissions  = "600"
      more_info           = "See http://oddthesis.org/theses/jboss-cloud/projects/jboss-cloud-support/pages/ec2-configuration-file for more info."
      aws_data            = @config.data['aws']

      #puts "AAAAAAAAAAAAAAA"
      #puts @config.config_file

      raise ValidationError, "Please specify aws section in configuration file (#{@config.config_file}). #{more_info}" if aws_data.nil?
      raise ValidationError, "Please specify path to cert in aws section in configuration file (#{@config.config_file}). #{more_info}" if aws_data['cert_file'].nil?
      raise ValidationError, "Please specify path to private key in aws secstion in configuration file (#{@config.config_file}). #{more_info}" if aws_data['key_file'].nil?
      raise ValidationError, "Please specify account number in aws secstion in configuration file (#{@config.config_file}). #{more_info}" if aws_data['account_number'].nil?
      raise ValidationError, "Please specify bucket name in aws secstion in configuration file (#{@config.config_file}). #{more_info}" if aws_data['bucket_name'].nil?
      raise ValidationError, "Please specify access key in aws secstion in configuration file (#{@config.config_file}). #{more_info}" if aws_data['access_key'].nil?
      raise ValidationError, "Please specify secret access key in aws secstion in configuration file (#{@config.config_file}). #{more_info}" if aws_data['secret_access_key'].nil?

      raise ValidationError, "Certificate file (cert_file) specified in configuration file (#{@config.config_file}) doesn't exists. Please check your path." unless File.exists?( aws_data['cert_file'] )
      raise ValidationError, "Private key file (key_file) specified in aws secstion in configuration file (#{@config.config_file}) doesn't exists. Please check your path." unless File.exists?( aws_data['key_file'] )

      cert_permission = sprintf( "%o", File.stat( aws_data['cert_file'] ).mode )[ 3, 5 ]
      key_permission = sprintf( "%o", File.stat( aws_data['key_file'] ).mode )[ 3, 5 ]

      raise ValidationError, "Certificate file (cert_file) specified in aws secstion in configuration file (#{@config.config_file}) has wrong permissions (#{cert_permission}), please correct it, run: 'chmod #{secure_permissions} #{aws_data['cert_file']}'." unless cert_permission.eql?( secure_permissions )
      raise ValidationError, "Private key file (key_file) specified in aws secstion in configuration file (#{@config.config_file}) has wrong permissions (#{key_permission}), please correct it, run: 'chmod #{secure_permissions} #{aws_data['key_file']}'." unless key_permission.eql?( secure_permissions )

      # remove dashes from account number
      aws_data['account_number'] = aws_data['account_number'].to_s.gsub(/-/, '')

      aws_data
    end
  end
end