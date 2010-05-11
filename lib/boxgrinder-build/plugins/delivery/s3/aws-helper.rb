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

module BoxGrinder
  class AWSHelper
    def initialize( config, appliance_config, plugin_config )
      @config           = config
      @appliance_config = appliance_config
      @plugin_config    = plugin_config

      # remove dashes from account number
      @plugin_config['account_number'] = @plugin_config['account_number'].to_s.gsub(/-/, '')

      @ec2        = AWS::EC2::Base.new(:access_key_id => @plugin_config['access_key'], :secret_access_key => @plugin_config['secret_access_key'])
      @s3         = AWS::S3::Base.establish_connection!(:access_key_id => @plugin_config['access_key'], :secret_access_key => @plugin_config['secret_access_key'] )
    end

    attr_reader :plugin_config
    attr_reader :ec2
    attr_reader :s3

    def bucket_key( appliance_name )
      "#{@plugin_config['bucket']}/#{appliance_name}/#{@appliance_config.version}.#{@appliance_config.release}/#{@appliance_config.hardware.arch}"
    end

    def bucket_manifest_key( appliance_name )
      "#{bucket_key( appliance_name )}/#{appliance_name}.ec2.manifest.xml"
    end

    def appliance_is_registered?( appliance_name )
      !ami_info( appliance_name ).nil?
    end

    def ami_info( appliance_name )
      ami_info = nil

      images = @ec2.describe_images( :owner_id => @plugin_config['account_number'] ).imagesSet

      return nil if images.nil?

      for image in images.item do
        ami_info = image if (image.imageLocation.eql?( bucket_manifest_key( appliance_name ) ))
      end

      ami_info
    end
  end
end