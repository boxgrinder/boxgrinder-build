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
require 'boxgrinder/validator/errors'
require 'boxgrinder/ssh/ssh-config'
require 'boxgrinder/helpers/ssh-helper'

module BoxGrinder
  class ApplianceUtils < Rake::TaskLib
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config

      @package_dir                  = "#{@config.dir.build}/appliances/#{@config.build_path}/packages/#{@config.arch}"
      @package_raw                  = "#{@package_dir}/#{@appliance_config.name}-#{@config.version_with_release}-#{@config.arch}-raw.tar.gz"
      @package_vmware               = "#{@package_dir}/#{@appliance_config.name}-#{@config.version_with_release}-#{@config.arch}-VMware.tar.gz"

      @appliance_raw_dir                   = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @appliance_vmware_dir                = "#{@appliance_raw_dir}/vmware"

      @exec_helper       = EXEC_HELPER
      @log               = LOG

      define_tasks
    end

    def define_tasks

      directory @package_dir

      task "appliance:#{@appliance_config.name}:upload:ssh" => [ "appliance:#{@appliance_config.name}:package" ] do
        prepare_file_list
        upload_via_ssh
      end

      task "appliance:#{@appliance_config.name}:upload:cloudfront" => [ "appliance:#{@appliance_config.name}:package" ] do
        prepare_file_list
        upload_to_cloudfront
      end

      task "appliance:#{@appliance_config.name}:package" => [ @package_raw, @package_vmware ]

      desc "Create RAW package for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:package:raw" => [ @package_raw ]

      desc "Create VMware package for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:package:vmware" => [ @package_vmware ]

      file @package_raw => [ @package_dir, "appliance:#{@appliance_config.name}" ] do
        @log.info "Packaging #{@appliance_config.simple_name} appliance RAW image (#{@config.os_name} #{@config.os_version}, #{@config.arch} arch)..."
        @exec_helper.execute "tar -C #{@appliance_raw_dir} -cvzf #{@package_raw} #{@appliance_config.name}-sda.raw #{@appliance_config.name}.xml"
        @log.info "RAW package created."
      end

      file @package_vmware => [ @package_dir, "appliance:#{@appliance_config.name}:vmware:enterprise", "appliance:#{@appliance_config.name}:vmware:personal" ] do
        @log.info "Packaging #{@appliance_config.simple_name} appliance VMware image (#{@config.os_name} #{@config.os_version}, #{@config.arch} arch)..."

        readme = File.open( "#{@config.dir.base}/src/README.vmware" ).read

        readme.gsub!( /#APPLIANCE_NAME#/, @appliance_config.name )
        readme.gsub!( /#NAME#/, @config.name )
        readme.gsub!( /#VERSION#/, @config.version_with_release )

        File.open( "#{@appliance_vmware_dir}/README", "w") {|f| f.write( readme ) }

        @exec_helper.execute "tar -C #{@appliance_vmware_dir} -cvzf '#{@package_vmware}' README #{@appliance_config.name}-sda.raw personal/#{@appliance_config.name}.vmx personal/#{@appliance_config.name}.vmdk enterprise/#{@appliance_config.name}.vmx enterprise/#{@appliance_config.name}.vmdk"
        @log.info "VMware package created."
      end
    end

    def validate_packages_upload_config( ssh_config )
      raise ValidationError, "Remote release packages path (remote_release_path) not specified in ssh section in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if ssh_config.cfg['remote_rpm_path'].nil?
    end

    def prepare_file_list
      path = "#{@config.version_with_release}/#{@appliance_config.hardware.arch}"

      raw_name                = File.basename( @package_raw )
      vmware_name             = File.basename( @package_vmware )

      @files = {}

      @files["#{path}/#{raw_name}"]       = @package_raw
      @files["#{path}/#{vmware_name}"]    = @package_vmware
    end

    def upload_via_ssh
      @log.info "Uploading '#{@appliance_config.name}' via ssh..."

      ssh_config = SSHConfig.new( @config )

      validate_packages_upload_config( ssh_config )

      ssh_helper = SSHHelper.new( ssh_config.options )
      ssh_helper.connect
      ssh_helper.upload_files( ssh_config.cfg['remote_release_path'], files )
      ssh_helper.disconnect

      @log.info "Appliance #{@appliance_config.simple_name} uploaded."
    end

    def upload_to_cloudfront

      bucket = @config.release.cloudfront['bucket_name']

      @log.info "Uploading '#{@appliance_config.name}' to CloudFront bucket '#{bucket}'..."

      AWSSupport.new( @config )

      begin
        AWS::S3::Bucket.find( bucket )
      rescue AWS::S3::NoSuchBucket => ex
        AWS::S3::Bucket.create( bucket )
        retry
      end

      for key in @files.keys
        unless S3Object.exists?( key, bucket )
          AWS::S3::S3Object.store( key, open( @files[key] ), bucket, :access => :public_read )
        end
      end

      @log.info "Appliance #{@appliance_config.simple_name} uploaded."
    end
  end
end

#desc "Upload all appliance packages to server"
#task "appliance:upload:all"
