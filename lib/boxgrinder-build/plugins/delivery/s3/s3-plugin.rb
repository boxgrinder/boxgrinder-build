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
  class S3Plugin < BaseDeliveryPlugin

    def info
      {
              :name       => :s3,
              :type       => [:cloudfront, :ami, :s3],
              :full_name  => "Amazon Simple Storage Service (Amazon S3)"
      }
    end

    def after_init
      set_default_config_value('overwrite', false)
    end

    def execute(deliverables, type = :ami)
      validate_plugin_config(['bucket', 'access_key', 'secret_access_key', 'path'])

      case type
        when :s3
          upload_to_bucket(deliverables)
        when :cloudfront
          upload_to_bucket(deliverables, :public_read)
        when :ami
          raise "Not implemented!"
          #bundle_image(deliverables)
          #upload_image
          #register_image
      end
    end

    def upload_to_bucket(deliverables, permissions = :private)
      AWSHelper.new(@config, @appliance_config)

      package = PackageHelper.new(@config, @appliance_config, {:log => @log, :exec_helper => @exec_helper}).package(deliverables)

      @log.info "Uploading #{@appliance_config.name} appliance to S3 bucket '#{@plugin_config['bucket']}'..."

      begin
        AWS::S3::Bucket.find(@plugin_config['bucket'])
      rescue AWS::S3::NoSuchBucket
        AWS::S3::Bucket.create(@plugin_config['bucket'])
        retry
      end

      remote_path = "#{@plugin_config['path']}/#{File.basename(package)}"
      size_b      = File.size(package)

      unless S3Object.exists?(remote_path, @plugin_config['bucket']) or @plugin_config['overwrite']
        @log.info "Uploading #{File.basename(package)} (#{size_b/1024/1024}MB)..."
        AWS::S3::S3Object.store(remote_path, open(package), @plugin_config['bucket'], :access => permissions)
      end

      @log.info "Appliance #{@appliance_config.name} uploaded to S3."
    end


    def bundle_image(deliverables)
      @log.info "Bundling AMI..."

      @exec_helper.execute("ec2-bundle-image -i #{deliverables[:disk]} --kernel #{AWS_DEFAULTS[:kernel_id][@appliance_config.hardware.arch]} --ramdisk #{AWS_DEFAULTS[:ramdisk_id][@appliance_config.hardware.arch]} -c #{@aws_helper.aws_data['cert_file']} -k #{@aws_helper.aws_data['key_file']} -u #{@aws_helper.aws_data['account_number']} -r #{@appliance_config.hardware.arch} -d #{@appliance_config.path.dir.ec2.bundle}")

      @log.info "Bundling AMI finished."
    end

    def appliance_already_uploaded?
      begin
        bucket = Bucket.find(@aws_helper.aws_data['bucket_name'])
      rescue
        return false
      end

      manifest_location = @aws_helper.bucket_manifest_key(@appliance_config.name)
      manifest_location = manifest_location[manifest_location.index("/") + 1, manifest_location.length]

      for object in bucket.objects do
        return true if object.key.eql?(manifest_location)
      end

      false
    end

    def upload_image
      if appliance_already_uploaded?
        @log.debug "Image for #{@appliance_config.name} appliance is already uploaded, skipping..."
        return
      end

      @log.info "Uploading #{@appliance_config.name} AMI to bucket '#{@aws_helper.aws_data['bucket_name']}'..."

      @exec_helper.execute("ec2-upload-bundle -b #{@aws_helper.bucket_key(@appliance_config.name)} -m #{@appliance_config.path.file.ec2.manifest} -a #{@aws_helper.aws_data['access_key']} -s #{@aws_helper.aws_data['secret_access_key']} --retry")
    end

    def register_image
      ami_info    = @aws_helper.ami_info(@appliance_config.name)

      if ami_info
        @log.info "Image is registered under id: #{ami_info.imageId}"
        return
      else
        ami_info = @aws_helper.ec2.register_image(:image_location => @aws_helper.bucket_manifest_key(@appliance_config.name))
        @log.info "Image successfully registered under id: #{ami_info.imageId}."
      end
    end

  end
end