#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
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

require 'aws-sdk'
require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-build/plugins/delivery/s3/messages'
require 'boxgrinder-build/helpers/package-helper'
require 'boxgrinder-build/helpers/s3-helper'
require 'boxgrinder-build/helpers/ec2-helper'
require 'boxgrinder-build/helpers/banner-helper'

module BoxGrinder
  class S3Plugin < BasePlugin
    plugin :type => :delivery, :name => :s3, :full_name => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami]

    def after_init
      register_supported_os("fedora", ['13', '14', '15', '16'])
      register_supported_os("centos", ['5', '6'])
      register_supported_os("rhel", ['5', '6'])
      register_supported_os("sl", ['5', '6'])

      @ami_build_dir = "#{@dir.base}/ami"
      @ami_manifest = "#{@ami_build_dir}/#{@appliance_config.name}.ec2.manifest.xml"
    end

    def validate
      set_default_config_value('overwrite', false)
      set_default_config_value('kernel', false)
      set_default_config_value('ramdisk', false)
      set_default_config_value('path', '/')
      set_default_config_value('region', 'us-east-1')

      set_default_config_value('block_device_mappings', {}) do |k, m, v|
        EC2Helper::block_device_mappings_validator(k, m, v)
      end
      
      validate_plugin_config(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')

      subtype(:ami) do
        set_default_config_value('snapshot', false)
        validate_plugin_config(['cert_file', 'key_file', 'account_number'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')

        raise PluginValidationError, "AWS certificate file doesn't exists, please check the path: '#{@plugin_config['cert_file']}'." unless File.exists?(File.expand_path(@plugin_config['cert_file']))
        raise PluginValidationError, "AWS key file doesn't exists, please check the path: '#{@plugin_config['key_file']}'." unless File.exists?(File.expand_path(@plugin_config['key_file']))
      end

      @s3_endpoints = S3Helper::endpoints
      raise PluginValidationError, "Invalid region specified: #{@plugin_config['region']}. This plugin is only aware of the following regions: #{@s3_endpoints.keys.join(", ")}." unless @s3_endpoints.has_key?(@plugin_config['region'])

      @plugin_config['account_number'] = @plugin_config['account_number'].to_s.gsub(/-/, '')

      # Set global AWS configuration
      AWS.config(:access_key_id => @plugin_config['access_key'],
        :secret_access_key => @plugin_config['secret_access_key'],
        :ec2_endpoint => EC2Helper::endpoints[@plugin_config['region']][:endpoint],
        :s3_endpoint => @s3_endpoints[@plugin_config['region']][:endpoint],
        :max_retries => 5,
        :use_ssl => @plugin_config['use_ssl'])

      @ec2 = AWS::EC2.new
      @s3 = AWS::S3.new
      @s3helper = S3Helper.new(@ec2, @s3, :log => @log)
      @ec2helper = EC2Helper.new(@ec2, :log => @log)

      subtype(:ami) do
        # If there is an existing bucket, determine whether its location_constraint matches the region selected
        if existing_bucket = asset_bucket(false)
          raise PluginValidationError, "Existing bucket #{@plugin_config['bucket']} has a location constraint that does not match the region selected. " <<
            "AMI region and bucket location constraint must match." unless constraint_equal?(@plugin_config['region'], existing_bucket.location_constraint)
        end
      end

      @bucket = asset_bucket(true)
    end

    def execute
      case @type
        when :s3
          upload_to_bucket(@previous_deliverables)
        when :cloudfront
          upload_to_bucket(@previous_deliverables, :public_read)
        when :ami
          @log.info Banner.message(S3::Messages::EPHEMERAL_MESSAGE)
    
          ami_dir = ami_key(@appliance_config.name, @plugin_config['path'])
          ami_manifest_key = @s3helper.stub_s3obj(@bucket, "#{ami_dir}/#{@appliance_config.name}.ec2.manifest.xml")

          @log.debug "Going to check whether s3 object exists"

          if ami_manifest_key.exists? and @plugin_config['overwrite']
            @log.info "Object exists, attempting to deregister an existing image"
            deregister_image(ami_manifest_key) # Remove existing image
            @s3helper.delete_folder(@bucket, ami_dir) # Avoid triggering dupe detection
          end

          if !ami_manifest_key.exists? or @plugin_config['snapshot']
            @log.info "Doing bundle/snapshot"
            bundle_image(@previous_deliverables)
            upload_image(ami_dir)
          end
          register_image(ami_manifest_key)
      end
    end

    def upload_to_bucket(previous_deliverables, permissions = :private)
      register_deliverable(
          :package => "#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}-#{@appliance_config.os.name}-#{@appliance_config.os.version}-#{@appliance_config.hardware.arch}-#{current_platform}.tgz"
      )

      # quick and dirty workaround to use @deliverables[:package] later in code
      FileUtils.mv(@target_deliverables[:package], @deliverables[:package]) if File.exists?(@target_deliverables[:package])

      PackageHelper.new(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).package(File.dirname(previous_deliverables[:disk]), @deliverables[:package])

      remote_path = "#{@s3helper.parse_path(@plugin_config['path'])}#{File.basename(@deliverables[:package])}"
      size_m = File.size(@deliverables[:package])/1024**2
      s3_obj = @s3helper.stub_s3obj(@bucket,remote_path.gsub(/^\//, '').gsub(/\/\//, ''))
      # Does it really exist?
      obj_exists = s3_obj.exists?

      if !obj_exists or @plugin_config['overwrite']
        @log.info "Will overwrite existing file #{remote_path}" if obj_exists and @plugin_config['overwrite']
        @log.info "Uploading #{File.basename(@deliverables[:package])} (#{size_m}MB) to '#{@plugin_config['bucket']}#{remote_path}' path..."
        s3_obj.write(:file => @deliverables[:package],
                        :acl => permissions)
        @log.info "Appliance #{@appliance_config.name} uploaded to S3."
      else
        @log.info "File '#{@plugin_config['bucket']}#{remote_path}' already uploaded, skipping."
      end
    end

    def asset_bucket(create_if_missing = true, permissions = :private)
      @s3helper.bucket(:bucket => @plugin_config['bucket'],
        :create_if_missing => create_if_missing,
        :acl => permissions,
        :location_constraint => @s3_endpoints[@plugin_config['region']][:location]
      )
    end

    def bundle_image(deliverables)
      if @plugin_config['snapshot']
        @log.debug "Removing bundled image from local disk..."
        FileUtils.rm_rf(@ami_build_dir)
      end

      return if File.exists?(@ami_build_dir)

      @log.info "Bundling AMI..."

      FileUtils.mkdir_p(@ami_build_dir)

      cmd_str = "euca-bundle-image --ec2cert #{File.dirname(__FILE__)}/src/cert-ec2.pem " <<
        "-i #{deliverables[:disk]} " <<
        "--kernel #{@plugin_config['kernel'] || @s3_endpoints[@plugin_config['region']][:kernel][@appliance_config.hardware.base_arch.intern][:aki]} " <<
        "-c #{@plugin_config['cert_file']} "<<
        "-k #{@plugin_config['key_file']} " <<
        "-u #{@plugin_config['account_number']} " <<
        "-r #{@appliance_config.hardware.base_arch} " <<
        "-d #{@ami_build_dir} "

      cmd_str << "--ramdisk #{@plugin_config['ramdisk']}" if @plugin_config['ramdisk']

      @exec_helper.execute(cmd_str, :redacted => [@plugin_config['account_number'], @plugin_config['key_file'], @plugin_config['cert_file']])

      @log.info "Bundling AMI finished."
    end

    def upload_image(ami_dir)
      @log.info "Uploading #{@appliance_config.name} AMI to bucket '#{@plugin_config['bucket']}'..."

      endpoint = @plugin_config['url'] || "http://#{@s3_endpoints[@plugin_config['region']][:endpoint]}"

      cmd_str = "euca-upload-bundle " << 
        "-U #{endpoint} " <<
        "-b #{@plugin_config['bucket']}/#{ami_dir} " <<
        "-m #{@ami_manifest} " <<
        "-a #{@plugin_config['access_key']} " << 
        "-s #{@plugin_config['secret_access_key']}"

      @exec_helper.execute(cmd_str, :redacted => [@plugin_config['access_key'], @plugin_config['secret_access_key']])
    end

    def register_image(ami_manifest_key)
      if ami = ami_by_manifest_key(ami_manifest_key)
        @log.info "Image for #{@appliance_config.name} is already registered under id: #{ami.id} (region: #{@plugin_config['region']})."
      else
        optmap = { :image_location =>  "#{@plugin_config['bucket']}/#{ami_manifest_key.key}" }
        
        unless @plugin_config['block_device_mappings'].empty?
          optmap.merge!(:block_device_mappings => @plugin_config['block_device_mappings']) 
        end

        @log.debug("Options map: #{optmap.inspect}")

        ami = @ec2.images.create(optmap)
        @ec2helper.wait_for_image_state(:available, ami)
        @log.info "Image for #{@appliance_config.name} successfully registered under id: #{ami.id} (region: #{@plugin_config['region']})."
      end
    end

    def deregister_image(ami_manifest_key)
      if ami = ami_by_manifest_key(ami_manifest_key)
        @log.info "Preexisting image '#{ami.location}' for #{@appliance_config.name} will be de-registered, it had id: #{ami.id} (region: #{@plugin_config['region']})."
        ami.deregister
        @ec2helper.wait_for_image_death(ami)
      else # This occurs when the AMI is de-registered externally but the file structure is left intact in S3. In this instance, we simply overwrite and register the image as if it were "new".
        @log.debug "Possible dangling/unregistered AMI skeleton structure in S3, there is nothing to deregister"
      end
    end

    def ami_by_manifest_key(ami_manifest_key)
      ami = @ec2.images.with_owner(@plugin_config['account_number']).
          filter("manifest-location","#{@plugin_config['bucket']}/#{ami_manifest_key.key}")
      return nil unless ami.any?
      ami.first
    end

    def ami_key(appliance_name, path)
      base_path = "#{@s3helper.parse_path(path)}#{appliance_name}/#{@appliance_config.os.name}/#{@appliance_config.os.version}/#{@appliance_config.version}.#{@appliance_config.release}"

      return "#{base_path}/#{@appliance_config.hardware.arch}" unless @plugin_config['snapshot']

      @log.info "Determining snapshot name"
      snapshot = 1
      while @s3helper.stub_s3obj(@bucket, "#{base_path}-snapshot-#{snapshot}/#{@appliance_config.hardware.arch}/").exists?
        snapshot += 1
      end
      # Reuse the last key (if there was one)
      snapshot -=1 if snapshot > 1 and @plugin_config['overwrite']

      "#{base_path}-snapshot-#{snapshot}/#{@appliance_config.hardware.arch}"
    end

    # US default constraint is often represented as '' or nil
    def constraint_equal?(region, constraint) 
      [region, constraint].collect{ |v| v.nil? || v == '' ? 'us-east-1' : v }.reduce(:==)
    end
  end
end
