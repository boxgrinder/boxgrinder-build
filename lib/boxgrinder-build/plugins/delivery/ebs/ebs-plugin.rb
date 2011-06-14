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

    def validate
      raise PluginValidationError, "You try to run this plugin on invalid platform. You can run EBS delivery plugin only on EC2." unless valid_platform?

      @current_avaibility_zone = open('http://169.254.169.254/latest/meta-data/placement/availability-zone').string

      set_default_config_value('availability_zone', @current_avaibility_zone)
      set_default_config_value('delete_on_termination', true)
      validate_plugin_config(['access_key', 'secret_access_key', 'account_number'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EBS_Delivery_Plugin')

      raise PluginValidationError, "You can only convert to EBS type AMI appliances converted to EC2 format. Use '-p ec2' switch. For more info about EC2 plugin see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EC2_Platform_Plugin." unless @previous_plugin_info[:name] == :ec2
      raise PluginValidationError, "You selected #{@plugin_config['availability_zone']} avaibility zone, but your instance is running in #{@current_avaibility_zone} zone. Please change avaibility zone in plugin configuration file to #{@current_avaibility_zone} (see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EBS_Delivery_Plugin) or use another instance in #{@plugin_config['availability_zone']} zone to create your EBS AMI." if @plugin_config['availability_zone'] != @current_avaibility_zone
    end

    def after_init
      @region = @current_avaibility_zone.scan(/((\w+)-(\w+)-(\d+))/).flatten.first

      register_supported_os('fedora', ['13', '14', '15'])
      register_supported_os('rhel', ['6'])
      register_supported_os('centos', ['5'])
    end

    def snapshot_info(snapshot_id)
      @ec2.describe_snapshots(:snapshot_id => snapshot_id).snapshotSet.item.each do |snapshot|
        return snapshot if snapshot_id == snapshot.snapshotId   
      end
      nil
    end

    def block_device_from_ami(ami_info, device_name)
      ami_info.blockDeviceMapping.item.each do |device|
        return device if device.deviceName.eql?(device_name)
      end
      nil
    end

    def get_instances(ami_id)
      #EC2 Gem has yet to be updated with new filters, once the patches have been pulled then it will be picked up
      instances_info = @ec2.describe_instances(:image_id => ami_id).reservationSet
      instances=[]
      instances_info["item"].each do
        |item| item["instancesSet"]["item"].each do |i|
          instances.push i if i.imageId == ami_id #TODO remove check once gem update occurs
        end
      end
      return instances.uniq unless instances.empty?
      nil
    end

    def stomp_ebs(ami_info)

      device = block_device_from_ami(ami_info, ROOT_DEVICE_NAME)

      if device
        snapshot_info = snapshot_info(device.ebs.snapshotId)
        volume_id = snapshot_info.volumeId

        @log.info "Finding any existing image with the block store attached"

        if instances = get_instances(ami_info.imageId)
          raise "There are still instances of #{ami_info.imageId} running, you must stop them: #{instances.join(",")}"
        end

        begin
          @log.debug "Forcibly detaching block store #{volume_id}"
          @ec2.detach_volume(:volume_id => volume_id, :force => true)

          #TODO check-wait cycle to determine that detachment has occurred successfully before continuing to delete.

          @log.debug "Deleting block store"
          @ec2.delete_volume(:volume_id => volume_id)
        rescue => e #error messages seem to be misleading
          @log.info "An error occurred when attempting to detach and delete old volume #{volume_id}, it may have already deleted, or is a ghost entry."
          @log.debug e
        ensure
          # ensure that the volume is _really_ gone? There is no guarantee that they won't hang around according to the API
        end

        @log.debug "Deregistering AMI"

        @ec2.deregister_image(:image_id => ami_info.imageId)

        unless @plugin_config['preserve_snapshots']
          @log.debug "Deleting snapshot #{device.ebs.snapshotId}"
          @ec2.delete_snapshot(:snapshot_id => snapshot_info.snapshotId)
        end

      else
        @log.error "The device #{ROOT_DEVICE_NAME} was not found, and therefore can not be unmounted"
        return false
      end
      true
    end

    def execute
      ebs_appliance_description = "#{@appliance_config.summary} | Appliance version #{@appliance_config.version}.#{@appliance_config.release} | #{@appliance_config.hardware.arch} architecture"

      @ec2 = AWS::EC2::Base.new(:access_key_id => @plugin_config['access_key'], :secret_access_key => @plugin_config['secret_access_key'])

      @log.debug "Checking if appliance is already registered..."

      ami_info = ami_info(ebs_appliance_name)

      @log.debug ami_info

      if ami_info and @plugin_config['overwrite']
        @log.info "Overwrite is enabled. Stomping existing assets"
        stomp_ebs(ami_info)
      elsif ami_info
        @log.warn "EBS AMI '#{ebs_appliance_name}' is already registered as '#{ami_id}' (region: #{@region})."
        return
      end

      @log.info "Creating new EBS volume..."

      size = 0

      @appliance_config.hardware.partitions.each_value { |partition| size += partition['size'] }

      # create_volume, ceiling to avoid fractions as per https://issues.jboss.org/browse/BGBUILD-224
      volume_id = @ec2.create_volume(:size => size.ceil.to_s, :availability_zone => @plugin_config['availability_zone'])['volumeId']

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

      sleep 10 # let's wait to discover the attached volume by OS

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

      @log.info "EBS AMI '#{ebs_appliance_name}' registered: #{image_id} (region: #{@region})"
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

    def wait_for_snapshot_status(status, snapshot_id)
      snapshot = @ec2.describe_snapshots(:snapshot_id => snapshot_id)['snapshotSet']['item'].first

      unless snapshot['status'] == status
        sleep 2
        wait_for_snapshot_status(status, snapshot_id)
      end
    end

    def wait_for_volume_status(status, volume_id)
      volume = @ec2.describe_volumes(:volume_id => volume_id)['volumeSet']['item'].first

      unless volume['status'] == status
        sleep 2
        wait_for_volume_status(status, volume_id)
      end
    end

    def device_for_suffix(suffix)
      return "/dev/sd#{suffix}" if File.exists?("/dev/sd#{suffix}")
      return "/dev/xvd#{suffix}" if File.exists?("/dev/xvd#{suffix}")

      raise "Device for suffix '#{suffix}' not found!"
    end

    def free_device_suffix
      ("f".."p").each do |suffix|
        return suffix unless File.exists?("/dev/sd#{suffix}") or File.exists?("/dev/xvd#{suffix}")
      end

      raise "Found too many attached devices. Cannot attach EBS volume."
    end

    def valid_platform?
      begin
        return Resolv.getname("169.254.169.254").include?(".ec2.internal")
      rescue Resolv::ResolvError
        false
      end
    end
  end
end

plugin :class => BoxGrinder::EBSPlugin, :type => :delivery, :name => :ebs, :full_name => "Elastic Block Storage"
