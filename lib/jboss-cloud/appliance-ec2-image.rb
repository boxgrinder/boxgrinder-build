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
      
      @ec2_data_file = "#{ENV['HOME']}/.jboss-cloud/ec2"
      
      define_tasks
    end
    
    def validate_config
      if File.exists?( @ec2_data_file )
        @ec2_data = YAML.load_file( @ec2_data_file )
      else
        raise ValidationError, "EC2 configuration file (#{@ec2_data_file}), doesn't exists. Please create."
      end
      
      raise ValidationError, "Please specify path to cert in EC2 configuration file (#{@ec2_data_file}). See http://oddthesis.org/theses/jboss-cloud/projects/jboss-cloud-support/pages/ec2-configuration-file for more info." if @ec2_data['cert_file'].nil?
      raise ValidationError, "Please specify path to private key in EC2 configuration file (#{@ec2_data_file}). See http://oddthesis.org/theses/jboss-cloud/projects/jboss-cloud-support/pages/ec2-configuration-file for more info." if @ec2_data['key_file'].nil?
      raise ValidationError, "Please specify account number in EC2 configuration file (#{@ec2_data_file}). See http://oddthesis.org/theses/jboss-cloud/projects/jboss-cloud-support/pages/ec2-configuration-file for more info." if @ec2_data['account_number'].nil?
      
      # remove dashes from account number
      @ec2_data['account_number'] = @ec2_data['account_number'].to_s.gsub(/-/, '')      
    end
    
    def define_tasks
      file @appliance_ec2_image_file  => [ @appliance_xml_file ] do
        convert_image_to_ec2_format
      end
      
      file @appliance_ec2_manifest_file => [ @appliance_ec2_image_file ] do
        bundle_image
      end
      
      task "testbleh" do
        bundle_image
      end
      
      desc "Build #{@appliance_config.simple_name} appliance for Amazon EC2"
      task "appliance:#{@appliance_config.name}:ec2" => [ @appliance_ec2_image_file ]
    end
    
    
    def bundle_image
      validate_config
      
      FileUtils.mkdir_p( @bundle_dir )
      
      command = "ec2-bundle-image -i #{@appliance_ec2_image_file} -c #{certs[0]} -k #{pks[0]} -u #{@nb} -r #{@config.build_arch} -d #{@bundle_dir}"
      exit_status =  execute_command( command )
      
      unless exit_status
        puts "\nBundling #{@appliance_config.simple_name} image failed! Hint: consult above messages.\n\r"
        abort
      end
    end
    
    def upload_image
      # ec2-upload-bundle -b [MAH_BUCKET] -m /tmp/ec2-[TIMESTAMP].img.manifest.xml -a [ACCESS_KEY] -s [SECRET_ACCESS_KEY] /tmp/ec2-[TIMESTAMP].img.manifest.xml
    end
    
    def register_ami
      # ec2-register -C [/Path/To/Cert] -K [/Path/To/Key] [MAH_BUCKET]/ec2-[TIMESTAMP].img.manifest.xml
    end
    
    def convert_image_to_ec2_format
      puts "Converting #{@appliance_config.simple_name} appliance image to EC2 format..."
      
      raw_file = "#{@appliance_build_dir}/#{@appliance_config.name}-sda.raw"
      tmp_dir = "#{@config.dir.build}/appliances/#{@config.build_path}/tmp/ec2-image-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"
      
      FileUtils.mkdir_p( tmp_dir )
      
      # we're using ec2-converter from thincrust appliance tools (http://thincrust.net/tooling.html)
      command = "sudo ec2-converter -f #{raw_file} --inputtype diskimage -n #{@appliance_ec2_image_file} -t #{tmp_dir}"
      
      exit_status =  execute_command( command )
      
      unless exit_status
        puts "\nConverting #{@appliance_config.simple_name} to EC2 format failed! Hint: consult above messages.\n\r"
        abort
      end
    end
    
  end
end
