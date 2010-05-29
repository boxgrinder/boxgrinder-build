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
require 'boxgrinder-build/plugins/delivery/s3/aws-helper'
require 'AWS'
require 'aws/s3'
include AWS::S3

module BoxGrinder
  class S3Plugin < BaseDeliveryPlugin

    AMI_OSES = {
            'fedora' => [ '11' ],
            'rhel' => [ '5' ]
    }

    KERNELS = {
            'us_east' => {
                    'fedora' => {
                            '11' => {
                                    'i386'     => { :aki => 'aki-a71cf9ce', :ari => 'ari-a51cf9cc' },
                                    'x86_64'   => { :aki => 'aki-b51cf9dc', :ari => 'ari-b31cf9da' }
                            }
                    },
                    'rhel' => {
                            '5' => {
                                    'i386'     => { :aki => 'aki-e3a54b8a', :ari => 'ari-f9a54b90' },
                                    'x86_64'   => { :aki => 'aki-ffa54b96', :ari => 'ari-fda54b94' }
                            }
                    }
            }
    }

    def info
      {
              :name       => :s3,
              :type       => [:cloudfront, :ami, :s3],
              :full_name  => "Amazon Simple Storage Service (Amazon S3)"
      }
    end

    def after_init
      set_default_config_value('overwrite', false)
      set_default_config_value('path', '/')

      @ami_build_dir  = "#{@appliance_config.path.dir.build}/ec2/ami"
      @ami_manifest   = "#{@ami_build_dir}/#{@appliance_config.name}.ec2.manifest.xml"
    end

    def supported_os
      supported = ""

      AMI_OSES.each_key do |os_name|
        supported << "#{os_name}, versions: #{AMI_OSES[os_name].join(", ")}"
      end

      supported
    end

    def execute( deliverables, type = :ami )
      validate_plugin_config(['bucket', 'access_key', 'secret_access_key'])

      @aws_helper = AWSHelper.new( @config, @appliance_config, @plugin_config )

      case type
        when :s3
          upload_to_bucket(deliverables)
        when :cloudfront
          upload_to_bucket(deliverables, :public_read)
        when :ami
          validate_plugin_config(['cert_file', 'key_file'])

          unless AMI_OSES[@appliance_config.os.name].include?(@appliance_config.os.version)
            @log.error "You cannot convert selected image to AMI because of unsupported operating system: #{@appliance_config.os.name} #{@appliance_config.os.version}. Supported systems: #{supported_os}."
            return
          end

          unless image_already_uploaded?
            bundle_image( deliverables )
            upload_image
          else
            @log.debug "AMI for #{@appliance_config.name} appliance already uploaded, skipping..."
          end

          register_image
      end
    end

    def upload_to_bucket(deliverables, permissions = :private)
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


    def bundle_image( deliverables )
      return if File.exists?( @ami_build_dir )

      @log.info "Bundling AMI..."

      FileUtils.mkdir_p( @ami_build_dir )

      @exec_helper.execute("ec2-bundle-image -i #{deliverables[:disk]} --kernel #{KERNELS['us_east'][@appliance_config.os.name][@appliance_config.os.version][@appliance_config.hardware.arch][:aki]} --ramdisk #{KERNELS['us_east'][@appliance_config.os.name][@appliance_config.os.version][@appliance_config.hardware.arch][:ari]} -c #{@plugin_config['cert_file']} -k #{@plugin_config['key_file']} -u #{@plugin_config['account_number']} -r #{@appliance_config.hardware.arch} -d #{@ami_build_dir}")

      @log.info "Bundling AMI finished."
    end

    def image_already_uploaded?
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
      @log.info "Uploading #{@appliance_config.name} AMI to bucket '#{@plugin_config['bucket']}'..."

      @exec_helper.execute("ec2-upload-bundle -b #{@aws_helper.bucket_key(@appliance_config.name)} -m #{@ami_manifest} -a #{@plugin_config['access_key']} -s #{@plugin_config['secret_access_key']} --retry")
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