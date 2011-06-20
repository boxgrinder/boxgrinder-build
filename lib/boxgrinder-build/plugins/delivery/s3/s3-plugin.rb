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

require 'rubygems'
require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-build/helpers/package-helper'
require 'AWS'
require 'aws'

module BoxGrinder
  class S3Plugin < BasePlugin
    REGION_OPTIONS = {
        'eu-west-1' => {
            :endpoint => 's3.amazonaws.com',
            :location => 'EU',
            :kernel => {
                'i386' => {:aki => 'aki-4deec439'},
                'x86_64' => {:aki => 'aki-4feec43b'}
            }
        },

        'ap-southeast-1' => {
            :endpoint => 's3-ap-southeast-1.amazonaws.com',
            :location => 'ap-southeast-1',
            :kernel => {
                'i386' => {:aki => 'aki-13d5aa41'},
                'x86_64' => {:aki => 'aki-11d5aa43'}
            }
        },

        'us-west-1' => {
            :endpoint => 's3-us-west-1.amazonaws.com',
            :location => 'us-west-1',
            :kernel => {
                'i386' => {:aki => 'aki-99a0f1dc'},
                'x86_64' => {:aki => 'aki-9ba0f1de'}
            }
        },

        'us-east-1' => {
            :endpoint => 's3.amazonaws.com',
            :location => '',
            :kernel => {
                'i386' => {:aki => 'aki-407d9529'},
                'x86_64' => {:aki => 'aki-427d952b'}
            }
        }
    }

    def after_init
      register_supported_os("fedora", ['13', '14', '15'])
      register_supported_os("centos", ['5'])
      register_supported_os("rhel", ['5', '6'])
      register_supported_os("sl", ['5', '6'])

      @ami_build_dir = "#{@dir.base}/ami"
      @ami_manifest = "#{@ami_build_dir}/#{@appliance_config.name}.ec2.manifest.xml"
    end

    def validate
      set_default_config_value('overwrite', false)
      set_default_config_value('path', '/')
      set_default_config_value('region', 'us-east-1')
      validate_plugin_config(['bucket', 'access_key', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')

      subtype(:ami) do
        set_default_config_value('snapshot', false)
        validate_plugin_config(['cert_file', 'key_file', 'account_number'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#S3_Delivery_Plugin')
      end
    end

  def execute
    case @type
      when :s3
        upload_to_bucket(@previous_deliverables)
      when :cloudfront
        upload_to_bucket(@previous_deliverables, 'public-read')
      when :ami
        @plugin_config['account_number'] = @plugin_config['account_number'].to_s.gsub(/-/, '')

        @ec2 = AWS::EC2::Base.new(:access_key_id => @plugin_config['access_key'], :secret_access_key => @plugin_config['secret_access_key'], :server => "ec2.#{@plugin_config['region']}.amazonaws.com")

        ami_dir = ami_key(@appliance_config.name, @plugin_config['path'])
        ami_manifest_key = "#{ami_dir}/#{@appliance_config.name}.ec2.manifest.xml"

        if !s3_object_exists?(ami_manifest_key) or @plugin_config['snapshot']
          bundle_image(@previous_deliverables)
          fix_sha1_sum
          upload_image(ami_dir)
        else
          @log.debug "AMI for #{@appliance_config.name} appliance already uploaded, skipping..."
        end

        register_image(ami_manifest_key)
    end
  end

  # https://jira.jboss.org/browse/BGBUILD-34
  def fix_sha1_sum
    ami_manifest = File.open(@ami_manifest).read
    ami_manifest.gsub!('(stdin)= ', '')

    File.open(@ami_manifest, "w") { |f| f.write(ami_manifest) }
  end

  def upload_to_bucket(previous_deliverables, permissions = 'private')
    register_deliverable(
        :package => "#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}-#{@appliance_config.os.name}-#{@appliance_config.os.version}-#{@appliance_config.hardware.arch}-#{current_platform}.tgz"
    )

    # quick and dirty workaround to use @deliverables[:package] later in code
    FileUtils.mv(@target_deliverables[:package], @deliverables[:package]) if File.exists?(@target_deliverables[:package])

    PackageHelper.new(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).package(File.dirname(previous_deliverables[:disk]), @deliverables[:package])

    remote_path = "#{s3_path(@plugin_config['path'])}#{File.basename(@deliverables[:package])}"
    size_b = File.size(@deliverables[:package])

    key = bucket(true, permissions).key(remote_path.gsub(/^\//, '').gsub(/\/\//, ''))

    unless key.exists? or @plugin_config['overwrite']
      @log.info "Uploading #{File.basename(@deliverables[:package])} (#{size_b/1024/1024}MB) to '#{@plugin_config['bucket']}#{remote_path}' path..."
      key.put(open(@deliverables[:package]), permissions, :server => REGION_OPTIONS[@plugin_config['region']][:endpoint])
      @log.info "Appliance #{@appliance_config.name} uploaded to S3."
    else
      @log.info "File '#{@plugin_config['bucket']}#{remote_path}' already uploaded, skipping."
    end

    @s3.close_connection
  end

  def bucket(create_if_missing = true, permissions = 'private')
    @s3 ||= Aws::S3.new(@plugin_config['access_key'], @plugin_config['secret_access_key'], :connection_mode => :single, :logger => @log, :server => REGION_OPTIONS[@plugin_config['region']][:endpoint])
    @s3.bucket(@plugin_config['bucket'], create_if_missing, permissions, :location => REGION_OPTIONS[@plugin_config['region']][:location])
  end

  def bundle_image(deliverables)
    if @plugin_config['snapshot']
      @log.debug "Removing bundled image from local disk..."
      FileUtils.rm_rf(@ami_build_dir)
    end

    return if File.exists?(@ami_build_dir)

    @log.info "Bundling AMI..."

    FileUtils.mkdir_p(@ami_build_dir)

    @exec_helper.execute("euca-bundle-image --ec2cert #{File.dirname(__FILE__)}/src/cert-ec2.pem -i #{deliverables[:disk]} --kernel #{REGION_OPTIONS[@plugin_config['region']][:kernel][@appliance_config.hardware.base_arch][:aki]} -c #{@plugin_config['cert_file']} -k #{@plugin_config['key_file']} -u #{@plugin_config['account_number']} -r #{@appliance_config.hardware.base_arch} -d #{@ami_build_dir}", :redacted => [@plugin_config['account_number'], @plugin_config['key_file'], @plugin_config['cert_file']])

    @log.info "Bundling AMI finished."
  end

  def upload_image(ami_dir)
    bucket # this will create the bucket if needed
    @log.info "Uploading #{@appliance_config.name} AMI to bucket '#{@plugin_config['bucket']}'..."

    @exec_helper.execute("euca-upload-bundle -U #{@plugin_config['url'].nil? ? "http://#{REGION_OPTIONS[@plugin_config['region']][:endpoint]}" : @plugin_config['url']} -b #{@plugin_config['bucket']}/#{ami_dir} -m #{@ami_manifest} -a #{@plugin_config['access_key']} -s #{@plugin_config['secret_access_key']}", :redacted => [@plugin_config['access_key'], @plugin_config['secret_access_key']])
  end

  def register_image(ami_manifest_key)
    info = ami_info(ami_manifest_key)

    if info
      @log.info "Image for #{@appliance_config.name} is registered under id: #{info.imageId} (region: #{@plugin_config['region']})."
    else
      info = @ec2.register_image(:image_location => "#{@plugin_config['bucket']}/#{ami_manifest_key}")
      @log.info "Image for #{@appliance_config.name} successfully registered under id: #{info.imageId} (region: #{@plugin_config['region']})."
    end
  end

  def ami_info(ami_manifest_key)
    ami_info = nil

    images = @ec2.describe_images(:owner_id => @plugin_config['account_number']).imagesSet

    return nil if images.nil?

    for image in images.item do
      ami_info = image if (image.imageLocation.eql?("#{@plugin_config['bucket']}/#{ami_manifest_key}"))
    end

    ami_info
  end

  def s3_path(path)
    return '' if path == '/'

    "#{path.gsub(/^(\/)*/, '').gsub(/(\/)*$/, '')}/"
  end

  def ami_key(appliance_name, path)
    base_path = "#{s3_path(path)}#{appliance_name}/#{@appliance_config.os.name}/#{@appliance_config.os.version}/#{@appliance_config.version}.#{@appliance_config.release}"

    return "#{base_path}/#{@appliance_config.hardware.arch}" unless @plugin_config['snapshot']

    snapshot = 1

    while s3_object_exists?("#{base_path}-SNAPSHOT-#{snapshot}/#{@appliance_config.hardware.arch}/")
      snapshot += 1
    end

    "#{base_path}-SNAPSHOT-#{snapshot}/#{@appliance_config.hardware.arch}"
  end

  def s3_object_exists?(path)
    @log.trace "Checking if '#{path}' path exists in #{@plugin_config['bucket']}..."

    begin
      b = bucket(false)
      # Retrieve only one or no keys (if bucket is empty), throw an exception if bucket doesn't exists
      b.keys('max-keys' => 1)

      if b.key(path).exists?
        @log.trace "Path exists!"
        return true
      end
    rescue
    end
    @log.trace "Path doesn't exist!"
    false
  end
end
end

plugin :class => BoxGrinder::S3Plugin, :type => :delivery, :name => :s3, :full_name => "Amazon Simple Storage Service (Amazon S3)", :types => [:s3, :cloudfront, :ami]
