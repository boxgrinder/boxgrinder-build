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
      
      @ec2_data_file = "#{ENV['HOME']}/.jboss-cloud/ec2"
      
      define_tasks
    end
    
    def validate_config
      more_info = "See http://oddthesis.org/theses/jboss-cloud/projects/jboss-cloud-support/pages/ec2-configuration-file for more info."
      
      secure_permissions = "600"
      
      if File.exists?( @ec2_data_file )
        @ec2_data = YAML.load_file( @ec2_data_file )
      else
        raise ValidationError, "EC2 configuration file (#{@ec2_data_file}), doesn't exists. Please create it. #{more_info}"
      end
      
      conf_file_permissions = sprintf( "%o", File.stat( @ec2_data_file ).mode )[ 3, 5 ]
      
      raise ValidationError, "EC2 configuration file (#{@ec2_data_file}) has wrong permissions (#{conf_file_permissions}), please correct it, run: 'chmod #{secure_permissions} #{@ec2_data_file}'." unless conf_file_permissions.eql?( secure_permissions )      
      
      raise ValidationError, "Please specify path to cert in EC2 configuration file (#{@ec2_data_file}). #{more_info}" if @ec2_data['cert_file'].nil?
      raise ValidationError, "Please specify path to private key in EC2 configuration file (#{@ec2_data_file}). #{more_info}" if @ec2_data['key_file'].nil?
      raise ValidationError, "Please specify account number in EC2 configuration file (#{@ec2_data_file}). #{more_info}" if @ec2_data['account_number'].nil?
      raise ValidationError, "Please specify bucket name in EC2 configuration file (#{@ec2_data_file}). #{more_info}" if @ec2_data['bucket_name'].nil?
      raise ValidationError, "Please specify access key in EC2 configuration file (#{@ec2_data_file}). #{more_info}" if @ec2_data['access_key'].nil?
      raise ValidationError, "Please specify secret access key in EC2 configuration file (#{@ec2_data_file}). #{more_info}" if @ec2_data['secret_access_key'].nil?
      
      raise ValidationError, "Certificate file (cert_file) specified in EC2 configuration file (#{@ec2_data_file}) doesn't exists. Please check your path." unless File.exists?( @ec2_data['cert_file'] )
      raise ValidationError, "Private key file (key_file) specified in EC2 configuration file (#{@ec2_data_file}) doesn't exists. Please check your path." unless File.exists?( @ec2_data['key_file'] )
      
      cert_permission = sprintf( "%o", File.stat( @ec2_data['cert_file'] ).mode )[ 3, 5 ]
      key_permission = sprintf( "%o", File.stat( @ec2_data['key_file'] ).mode )[ 3, 5 ]
      
      raise ValidationError, "Certificate file (cert_file) specified in EC2 configuration file (#{@ec2_data_file}) has wrong permissions (#{cert_permission}), please correct it, run: 'chmod #{secure_permissions} #{@ec2_data['cert_file']}'." unless cert_permission.eql?( secure_permissions )
      raise ValidationError, "Private key file (key_file) specified in EC2 configuration file (#{@ec2_data_file}) has wrong permissions (#{key_permission}), please correct it, run: 'chmod #{secure_permissions} #{@ec2_data['key_file']}'." unless key_permission.eql?( secure_permissions )
      
      # remove dashes from account number
      @ec2_data['account_number'] = @ec2_data['account_number'].to_s.gsub(/-/, '')
      
      @ec2 = EC2::Base.new(:access_key_id => @ec2_data['access_key'], :secret_access_key => @ec2_data['secret_access_key'])
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
      
      desc "Build #{@appliance_config.simple_name} appliance for Amazon EC2"
      task "appliance:#{@appliance_config.name}:ec2" => [ @appliance_ec2_image_file ]
    end
    
    
    def bundle_image
      validate_config
      
      command = "ec2-bundle-image -i #{@appliance_ec2_image_file} -c #{@ec2_data['cert_file']} -k #{@ec2_data['key_file']} -u #{@ec2_data['account_number']} -r #{@config.build_arch} -d #{@bundle_dir}"
      exit_status =  execute_command( command )
      
      unless exit_status
        puts "\nBundling #{@appliance_config.simple_name} image failed! Hint: consult above messages.\n\r"
        abort
      end
    end
    
    def upload_image
      validate_config

      command =  "ec2-upload-bundle -b #{@ec2_data['bucket_name']} -m #{@appliance_ec2_manifest_file} -a #{@ec2_data['access_key']} -s #{@ec2_data['secret_access_key']} --retry"
      exit_status =  execute_command( command )
      
      unless exit_status
        puts "\nUploading #{@appliance_config.simple_name} image to Amazon failed! Hint: consult above messages.\n\r"
        abort
      end
    end
    
    def register_image
      validate_config
      
      registered = nil
      
      for image in @ec2.describe_images( :owner_id => @ec2_data['account_number'] ).imagesSet.item do
        registered = image if (image.imageLocation.eql?( "#{@ec2_data['bucket_name']}/#{File.basename( @appliance_ec2_manifest_file )}" ))
      end
      
      if registered
        puts "Image is already registered under id: #{registered.imageId}"
      else
        registered = @ec2.register_image( :image_location => "#{@ec2_data['bucket_name']}/#{File.basename( @appliance_ec2_manifest_file )}" )
        puts "Image successfully registered under id: #{registered.imageId}. Now you can run it using Elasticfox (http://developer.amazonwebservices.com/connect/entry.jspa?externalID=609) or AWS Management Console (https://console.aws.amazon.com/ec2/home)"
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
