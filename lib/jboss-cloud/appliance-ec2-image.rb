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

require 'rake/tasklib'
require 'fileutils'
require 'jboss-cloud/validator/errors'
require 'yaml'
require 'rubygems'
require 'EC2'
require 'aws/s3'
require 'jboss-cloud/aws/aws-support'
include AWS::S3

module JBossCloud
  class ApplianceEC2Image < Rake::TaskLib

    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config

      @appliance_build_dir          = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @bundle_dir                   = "#{@appliance_build_dir}/ec2/bundle"
      @appliance_xml_file           = "#{@appliance_build_dir}/#{@appliance_config.name}.xml"
      @appliance_ec2_image_file     = "#{@appliance_build_dir}/#{@appliance_config.name}-ec2.img"
      @appliance_ec2_manifest_file  = "#{@bundle_dir}/#{@appliance_config.name}-ec2.img.manifest.xml"
      @appliance_ec2_register_file  = "#{@appliance_build_dir}/ec2/register"

      define_tasks
    end

    def define_tasks
      directory @bundle_dir

      file @appliance_ec2_image_file  => [ @appliance_xml_file ] do
        convert_image_to_ec2_format
      end

      file @appliance_ec2_manifest_file => [ @appliance_ec2_image_file, @bundle_dir ] do
        bundle_image
      end

      task "appliance:#{@appliance_config.name}:ec2:upload" => [ @appliance_ec2_manifest_file ] do
        upload_image
      end

      task "appliance:#{@appliance_config.name}:ec2:register" => [ "appliance:#{@appliance_config.name}:ec2:upload" ] do
        register_image
      end


      task "appliance:#{@appliance_config.name}:ec2:list_buckets"  do
        upload_image
      end

      desc "Build #{@appliance_config.simple_name} appliance for Amazon EC2"
      task "appliance:#{@appliance_config.name}:ec2" => [ @appliance_ec2_image_file ]
    end

    def bundle_image
      aws_data = AWSSupport.instance.aws_data

      command = "ec2-bundle-image -i #{@appliance_ec2_image_file} -c #{aws_data['cert_file']} -k #{aws_data['key_file']} -u #{aws_data['account_number']} -r #{@config.build_arch} -d #{@bundle_dir}"
      exit_status =  execute_command( command )

      unless exit_status
        puts "\nBundling #{@appliance_config.simple_name} image failed! Hint: consult above messages.\n\r"
        abort
      end
    end

    def appliance_already_uploaded?
      aws_data = AWSSupport.instance.aws_data

      begin
        bucket = Bucket.find( aws_data['bucket_name'] )
      rescue
        return false
      end

      manifest_location = AWSSupport.instance.bucket_manifest_key( @appliance_config.name )
      manifest_location = manifest_location[ manifest_location.index( "/" ) + 1, manifest_location.length ]

      for object in bucket.objects do
        return true if object.key.eql?( manifest_location )
      end

      false
    end

    def upload_image
      aws_data  = AWSSupport.instance.aws_data
      s3        = AWSSupport.instance.s3

      if appliance_already_uploaded?
        puts "Image for #{@appliance_config.simple_name} appliance is already uploaded, skipping..."
        return
      end

      command = "ec2-upload-bundle -b #{AWSSupport.instance.bucket_key( @appliance_config.name )} -m #{@appliance_ec2_manifest_file} -a #{aws_data['access_key']} -s #{aws_data['secret_access_key']} --retry"
      exit_status = execute_command( command )

      unless exit_status
        puts "\nUploading #{@appliance_config.simple_name} image to Amazon failed! Hint: consult above messages.\n\r"
        abort
      end
    end

    def register_image
      ami_info    = AWSSupport.instance.ami_info( @appliance_config.name )
      ec2         = AWSSupport.instance.ec2

      if ami_info
        puts "Image is registered under id: #{ami_info.imageId}"
        return
      else
        ami_info = ec2.register_image( :image_location => AWSSupport.instance.bucket_manifest_key( @appliance_config.name ) )
        puts "Image successfully registered under id: #{ami_info.imageId}. Now you can run it using Elasticfox (http://developer.amazonwebservices.com/connect/entry.jspa?externalID=609) or AWS Management Console (https://console.aws.amazon.com/ec2/home)"
      end
    end

    def convert_image_to_ec2_format
      puts "Converting #{@appliance_config.simple_name} appliance image to EC2 format..."

      raw_file = "#{@appliance_build_dir}/#{@appliance_config.name}-sda.raw"
      tmp_dir = "#{@config.dir.build}/appliances/#{@config.build_path}/tmp/ec2-image-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

      FileUtils.mkdir_p( tmp_dir )

      # we're using ec2-converter from thincrust appliance tools (http://thincrust.net/tooling.html)
      command = "sudo ec2-converter -f #{raw_file} --inputtype diskimage -n #{@appliance_ec2_image_file} -t #{tmp_dir}"
      exit_status = execute_command( command )

      unless exit_status
        puts "\nConverting #{@appliance_config.simple_name} appliance to EC2 format failed! Hint: consult above messages.\n\r"
        abort
      end
    end

  end
end
