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
require 'AWS'
require 'open-uri'
require 'timeout'
require 'pp'

module BoxGrinder
  class EBSPlugin < BasePlugin
    KERNELS = {
        'eu-west-1' => {
            'i386' => {:aki => 'aki-4deec439'},
            'x86_64' => {:aki => 'aki-4feec43b'}
        },
        'ap-southeast-1' => {
            'i386' => {:aki => 'aki-13d5aa41'},
            'x86_64' => {:aki => 'aki-11d5aa43'}
        },
        'ap-northeast-1' => {
            'i386' => {:aki => 'aki-d209a2d3'},
            'x86_64' => {:aki => 'aki-d409a2d5'}
        },
        'us-west-1' => {
            'i386' => {:aki => 'aki-99a0f1dc'},
            'x86_64' => {:aki => 'aki-9ba0f1de'}
        },
        'us-east-1' => {
            'i386' => {:aki => 'aki-407d9529'},
            'x86_64' => {:aki => 'aki-427d952b'}
        }
    }

    ROOT_DEVICE_NAME = '/dev/sda1'
    POLL_FREQ = 1 #second
    TIMEOUT = 1000 #seconds
    EC2_HOSTNAME_LOOKUP_TIMEOUT = 10

    def validate
      raise PluginValidationError, "You try to run this plugin on invalid platform. You can run EBS delivery plugin only on EC2." unless valid_platform?

      @current_availability_zone = open('http://169.254.169.254/latest/meta-data/placement/availability-zone').string

      set_default_config_value('availability_zone', @current_availability_zone)
      set_default_config_value('delete_on_termination', true)
      set_default_config_value('overwrite', false)
      set_default_config_value('snapshot', false)
      set_default_config_value('preserve_snapshots', false)
      validate_plugin_config(['access_key', 'secret_access_key', 'account_number'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EBS_Delivery_Plugin')

      raise PluginValidationError, "You can only convert to EBS type AMI appliances converted to EC2 format. Use '-p ec2' switch. For more info about EC2 plugin see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EC2_Platform_Plugin." unless @previous_plugin_info[:name] == :ec2
      raise PluginValidationError, "You selected #{@plugin_config['availability_zone']} availability zone, but your instance is running in #{@current_availability_zone} zone. Please change availability zone in plugin configuration file to #{@current_availability_zone} (see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EBS_Delivery_Plugin) or use another instance in #{@plugin_config['availability_zone']} zone to create your EBS AMI." if @plugin_config['availability_zone'] != @current_availability_zone
    end

    def after_init
      @region = @current_availability_zone.scan(/((\w+)-(\w+)-(\d+))/).flatten.first

      register_supported_os('fedora', ['13', '14', '15'])
      register_supported_os('rhel', ['6'])
      register_supported_os('centos', ['5'])
    end

    def execute
      ebs_appliance_description = "#{@appliance_config.summary} | Appliance version #{@appliance_config.version}.#{@appliance_config.release} | #{@appliance_config.hardware.arch} architecture"

      @ec2 = AWS::EC2::Base.new(:access_key_id => @plugin_config['access_key'], :secret_access_key => @plugin_config['secret_access_key'])

      @log.debug "Checking if appliance is already registered..."

      ami_info = ami_info(ebs_appliance_name)

      @log.debug "AMI info #{ami_info}"

      if ami_info and @plugin_config['overwrite']
        @log.info "Overwrite is enabled. Stomping existing assets"
        stomp_ebs(ami_info)
      elsif ami_info
        @log.warn "EBS AMI '#{ebs_appliance_name}' is already registered as '#{ami_info.imageId}' (region: #{@region})."
        return
      end

      @log.info "Creating new EBS volume..."

      size = 0

      @appliance_config.hardware.partitions.each_value { |partition| size += partition['size'] }

      # create_volume, ceiling to avoid fractions as per https://issues.jboss.org/browse/BGBUILD-224
      volume_id = @ec2.create_volume(:size => size.ceil.to_s, :availability_zone => @plugin_config['availability_zone'])['volumeId']

      begin

      @log.debug "Volume #{volume_id} created."
      @log.debug "Waiting for EBS volume #{volume_id} to be available..."

      # wait for volume to be created
      wait_for_volume_status('available', volume_id)

      # get first free device to mount the volume
      suffix = free_device_suffix

      @log.trace "Got free device suffix: '#{suffix}'"
      @log.trace "Reading current instance id..."

      # read current instance id
      instance_id = open('http://169.254.169.254/latest/meta-data/instance-id').string

      @log.trace "Got: #{instance_id}"
      @log.info "Attaching created volume..."

      # attach the volume to current host
      @ec2.attach_volume(:device => "/dev/sd#{suffix}", :volume_id => volume_id, :instance_id => instance_id)

      @log.debug "Waiting for EBS volume to be attached..."

      # wait for volume to be attached
      wait_for_volume_status('in-use', volume_id)

      @log.debug "Waiting for the attached EBS volume to be discovered by the OS"

      wait_for_volume_attachment(suffix)  # add rescue block for timeout when no suffix can be found then re-raise

      @log.info "Copying data to EBS volume..."

      @image_helper.customize([@previous_deliverables.disk, device_for_suffix(suffix)], :automount => false) do |guestfs, guestfs_helper|
        @image_helper.sync_filesystem(guestfs, guestfs_helper)

        @log.debug "Adjusting /etc/fstab..."
        adjust_fstab(guestfs)
      end

      @log.debug "Detaching EBS volume..."

      @ec2.detach_volume(:device => "/dev/sd#{suffix}", :volume_id => volume_id, :instance_id => instance_id)

      @log.debug "Waiting for EBS volume to become available..."

      wait_for_volume_status('available', volume_id)

      @log.info "Creating snapshot from EBS volume..."

      snapshot_id = @ec2.create_snapshot(
          :volume_id => volume_id,
          :description => ebs_appliance_description)['snapshotId']

      @log.debug "Waiting for snapshot #{snapshot_id} to be completed..."

      wait_for_snapshot_status('completed', snapshot_id)

      @log.debug "Deleting temporary EBS volume..."

      @ec2.delete_volume(:volume_id => volume_id)

      @log.info "Registering image..."

      image_id = @ec2.register_image(
          :block_device_mapping => [{
                                        :device_name => '/dev/sda1',
                                        :ebs_snapshot_id => snapshot_id,
                                        :ebs_delete_on_termination => @plugin_config['delete_on_termination']
                                    },
                                    {
                                        :device_name => '/dev/sdb',
                                        :virtual_name => 'ephemeral0'
                                    },
                                    {
                                        :device_name => '/dev/sdc',
                                        :virtual_name => 'ephemeral1'
                                    },
                                    {
                                        :device_name => '/dev/sdd',
                                        :virtual_name => 'ephemeral2'
                                    },
                                    {
                                        :device_name => '/dev/sde',
                                        :virtual_name => 'ephemeral3'
                                    }],
          :root_device_name => ROOT_DEVICE_NAME,
          :architecture => @appliance_config.hardware.base_arch,
          :kernel_id => KERNELS[@region][@appliance_config.hardware.base_arch][:aki],
          :name => ebs_appliance_name,
          :description => ebs_appliance_description)['imageId']

      rescue Timeout::Error
        @log.error "Timed out. Manual intervention may be necessary to complete the task."
        raise
      end

      @log.info "EBS AMI '#{ebs_appliance_name}' registered: #{image_id} (region: #{@region})"
    end

    def get_volume_info(volume_id)
      begin
        @ec2.describe_volumes(:volume_id => volume_id).volumeSet.item.each do |volume|
          return volume if volume.volumeId == volume_id
        end
      rescue AWS::Error, AWS::InvalidVolumeIDNotFound => e# only InvalidVolumeIDNotFound should be returned when no volume found, but is not always doing so at present.
        @log.trace "Error getting volume info: #{e}"
        return nil
      end
      nil
    end

    def snapshot_info(snapshot_id)
     begin
      @ec2.describe_snapshots(:snapshot_id => snapshot_id).snapshotSet.item.each do |snapshot|
        return snapshot if snapshot.snapshotId == snapshot_id
      end
     rescue AWS::InvalidSnapshotIDNotFound
       return nil
     end
      nil
    end

    def block_device_from_ami(ami_info, device_name)
      ami_info.blockDeviceMapping.item.each do |device|
        return device if device.deviceName == device_name
      end
      nil
    end

    def get_instances(ami_id)
      #EC2 Gem has yet to be updated with new filters, once the patches have been pulled then :image_id filter will be picked up
      instances_info = @ec2.describe_instances(:image_id => ami_id).reservationSet
      instances=[]
      instances_info["item"].each do
        |item| item["instancesSet"]["item"].each do |i|
          instances.push i if i.imageId == ami_id #TODO remove check after gem update
        end
      end
      return instances.uniq unless instances.empty?
      nil
    end

    def stomp_ebs(ami_info)

      device = block_device_from_ami(ami_info, ROOT_DEVICE_NAME)

      if device #if there is the anticipated device on the image
        snapshot_info = snapshot_info(device.ebs.snapshotId)
        volume_id = snapshot_info.volumeId
        volume_info = get_volume_info(volume_id)

        @log.trace "volume_info for #{volume_id} : #{volume_info}"
        @log.info "Finding any existing image with the block store attached"

        if instances = get_instances(ami_info.imageId)
          raise "There are still instances of #{ami_info.imageId} running, you must stop them: #{instances.join(",")}"
        end

        if volume_info #if the physical volume exists
          unless volume_info.status == 'available'
            begin
             @log.info "Forcibly detaching block store #{volume_info.volumeId}"
             @ec2.detach_volume(:volume_id => volume_info.volumeId, :force => true)
            rescue AWS::IncorrectState
             @log.debug "State of the volume has changed, our data must have been stale. This should not be fatal."
            end
          end

          @log.debug "Waiting for volume to become detached"
          wait_for_volume_status('available', volume_info.volumeId)

          begin
            @log.info "Deleting block store"
            @ec2.delete_volume(:volume_id => volume_info.volumeId)
            @log.debug "Waiting for volume deletion to be confirmed"
            wait_for_volume_status('deleted', volume_info.volumeId)
          rescue AWS::InvalidVolumeIDNotFound
            @log.debug "An external entity has probably deleted the volume just before we tried to. This should not be fatal."
          end
        end

        begin
          @log.debug "Deregistering AMI"
          @ec2.deregister_image(:image_id => ami_info.imageId)
        rescue AWS::InvalidAMIIDUnavailable, AWS::InvalidAMIIDNotFound
          @log.debug "An external entity has already deregistered the AMI just before we tried to. This should not be fatal."
        end

        if !@plugin_config['preserve_snapshots'] and snapshot_info #if the snapshot exists
         begin
          @log.debug "Deleting snapshot #{snapshot_info.snapshotId}"
          @ec2.delete_snapshot(:snapshot_id => snapshot_info.snapshotId)
         rescue AWS::InvalidSnapshotIDNotFound
          @log.debug "An external entity has probably deleted the snapshot just before we tried to. This should not be fatal."
         end
        end
      else
        @log.error "Expected device #{ROOT_DEVICE_NAME} was not found on the image."
        return false
      end
      true
    end

    def ebs_appliance_name
      base_path = "#{@appliance_config.name}/#{@appliance_config.os.name}/#{@appliance_config.os.version}/#{@appliance_config.version}.#{@appliance_config.release}"

      return "#{base_path}/#{@appliance_config.hardware.arch}" unless @plugin_config['snapshot']

      snapshot = 1

      while already_registered?("#{base_path}-SNAPSHOT-#{snapshot}/#{@appliance_config.hardware.arch}")
        snapshot += 1
      end
      # Reuse the last key (if there was one)
      snapshot -=1 if snapshot > 1 and @plugin_config['overwrite']

      "#{base_path}-SNAPSHOT-#{snapshot}/#{@appliance_config.hardware.arch}"
    end

    def ami_info(name)
      images = @ec2.describe_images(:owner_id => @plugin_config['account_number'].to_s.gsub(/-/,''))
      return false if images.nil?
      images = images.imagesSet

      for image in images.item do
        return image if image.name == name
      end
      false
    end

    def already_registered?(name)
      info = ami_info(name)
      return info.imageId if info
      false
    end

    def adjust_fstab(guestfs)
      guestfs.sh("cat /etc/fstab | grep -v '/mnt' | grep -v '/data' | grep -v 'swap' > /etc/fstab.new")
      guestfs.mv("/etc/fstab.new", "/etc/fstab")
    end

    def wait_with_timeout(cycle_seconds, timeout_seconds)
      Timeout::timeout(timeout_seconds) do
        while not yield
          sleep cycle_seconds
        end
      end
    end

    def wait_for_volume_attachment(suffix)
      wait_with_timeout(POLL_FREQ, TIMEOUT){ device_for_suffix(suffix) != nil }
    end

    def wait_for_snapshot_status(status, snapshot_id)
      progress = -1
      wait_with_timeout(POLL_FREQ, TIMEOUT) do
        snapshot = @ec2.describe_snapshots(:snapshot_id => snapshot_id)['snapshotSet']['item'].first
        current_progress = snapshot.progress.to_i 
        unless progress == current_progress 
          @log.info "Progress: #{current_progress}%"
          progress = current_progress
        end
        @log.trace "Polling @ec2.describe_snapshots for #{snapshot_id} with status #{status}: #{PP::pp(snapshot,"")}, current status is #{snapshot['status']}"  
        snapshot['status'] == status
      end
    end

    def wait_for_volume_status(status, volume_id)
      wait_with_timeout(POLL_FREQ, TIMEOUT) do
        volume = @ec2.describe_volumes(:volume_id => volume_id)['volumeSet']['item'].first
        @log.trace "Polling @ec2.describe_volumes for #{volume_id} with status #{status}: #{PP::pp(volume,"")}, current status is #{volume['status']}"
        volume['status'] == status
      end
    end

    def device_for_suffix(suffix)
      return "/dev/sd#{suffix}" if File.exists?("/dev/sd#{suffix}")
      return "/dev/xvd#{suffix}" if File.exists?("/dev/xvd#{suffix}")
      nil
      #raise "Device for suffix '#{suffix}' not found!"
    end

    def free_device_suffix
      ("f".."p").each do |suffix|
        return suffix unless File.exists?("/dev/sd#{suffix}") or File.exists?("/dev/xvd#{suffix}")
      end
      raise "Found too many attached devices. Cannot attach EBS volume."
    end

    def get_ec2_hostname
      timeout(EC2_HOSTNAME_LOOKUP_TIMEOUT) do

        req = Net::HTTP::Get.new('/1.0/meta-data/hostname')
        res = Net::HTTP.start('169.254.169.254', 80) {|http|
        http.request(req)
      }
        case res
        when Net::HTTPSuccess
          res.body
        else
          res.error!
        end
      end
    end

    def valid_platform?
      begin
        return get_ec2_hostname.include?(".ec2.internal")
      rescue Net::HTTPServerException => e
        @log.warn "An error was returned when attempting to retrieve the ec2 hostname: #{e}"
      rescue Timeout::Error => t
        @log.warn "A timeout occurred while attempting to retrieve the ec2 hostname: #{t}"
      end
      false
    end

  end
end

plugin :class => BoxGrinder::EBSPlugin, :type => :delivery, :name => :ebs, :full_name => "Elastic Block Storage"
