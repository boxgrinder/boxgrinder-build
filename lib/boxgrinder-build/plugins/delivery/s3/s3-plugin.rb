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

require 'boxgrinder-build/plugins/delivery/base/base-delivery-plugin'
require 'boxgrinder-build/helpers/aws-helper'
require 'AWS'
require 'aws/s3'
include AWS::S3

module BoxGrinder
  class AMIPlugin < BaseDeliveryPlugin

    def info
      {
              :name       => :s3,
              :full_name  => "Amazon Simple Storage Service (Amazon S3)"
      }
    end

    def upload( disk )
    end

    def bundle_image
      @log.info "Bundling AMI..."

      @exec_helper.execute( "ec2-bundle-image -i #{@appliance_config.path.file.ec2.disk} --kernel #{AWS_DEFAULTS[:kernel_id][@appliance_config.hardware.arch]} --ramdisk #{AWS_DEFAULTS[:ramdisk_id][@appliance_config.hardware.arch]} -c #{@aws_helper.aws_data['cert_file']} -k #{@aws_helper.aws_data['key_file']} -u #{@aws_helper.aws_data['account_number']} -r #{@appliance_config.hardware.arch} -d #{@appliance_config.path.dir.ec2.bundle}" )

      @log.info "Bundling AMI finished."
    end

    def appliance_already_uploaded?
      begin
        bucket = Bucket.find( @aws_helper.aws_data['bucket_name'] )
      rescue
        return false
      end

      manifest_location = @aws_helper.bucket_manifest_key( @appliance_config.name )
      manifest_location = manifest_location[ manifest_location.index( "/" ) + 1, manifest_location.length ]

      for object in bucket.objects do
        return true if object.key.eql?( manifest_location )
      end

      false
    end

    def upload_image
      if appliance_already_uploaded?
        @log.debug "Image for #{@appliance_config.name} appliance is already uploaded, skipping..."
        return
      end

      @log.info "Uploading #{@appliance_config.name} AMI to bucket '#{@aws_helper.aws_data['bucket_name']}'..."

      @exec_helper.execute( "ec2-upload-bundle -b #{@aws_helper.bucket_key( @appliance_config.name )} -m #{@appliance_config.path.file.ec2.manifest} -a #{@aws_helper.aws_data['access_key']} -s #{@aws_helper.aws_data['secret_access_key']} --retry" )
    end

    def register_image
      ami_info    = @aws_helper.ami_info( @appliance_config.name )

      if ami_info
        @log.info "Image is registered under id: #{ami_info.imageId}"
        return
      else
        ami_info = @aws_helper.ec2.register_image( :image_location => @aws_helper.bucket_manifest_key( @appliance_config.name ) )
        @log.info "Image successfully registered under id: #{ami_info.imageId}."
      end
    end

  end
end