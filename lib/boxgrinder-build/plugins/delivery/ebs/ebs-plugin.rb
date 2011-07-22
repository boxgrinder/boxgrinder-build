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
require 'boxgrinder-build/helpers/ec2-helper'
require 'aws-sdk'
require 'open-uri'
require 'timeout'
require 'pp'

module BoxGrinder
  class EBSPlugin < BasePlugin

    ROOT_DEVICE_NAME = '/dev/sda1'
    POLL_FREQ = 1 #second
    TIMEOUT = 1000 #seconds
    EC2_HOSTNAME_LOOKUP_TIMEOUT = 10

    def validate
      @ec2_endpoints = EC2Helper::endpoints

      raise PluginValidationError, "You are trying to run this plugin on an invalid platform. You can run the EBS delivery plugin only on EC2." unless valid_platform?

      @current_availability_zone = EC2Helper::current_availability_zone
      @current_instance_id = EC2Helper::current_instance_id
      @current_region = EC2Helper::availability_zone_to_region(@current_availability_zone)

      set_default_config_value('availability_zone', @current_availability_zone)
      set_default_config_value('delete_on_termination', true)
      set_default_config_value('overwrite', false)
      set_default_config_value('snapshot', false)
      set_default_config_value('preserve_snapshots', false)
      set_default_config_value('terminate_instances', false)
      validate_plugin_config(['access_key', 'secret_access_key', 'account_number'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EBS_Delivery_Plugin')

      raise PluginValidationError, "You can only convert to EBS type AMI appliances converted to EC2 format. Use '-p ec2' switch. For more info about EC2 plugin see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EC2_Platform_Plugin." unless @previous_plugin_info[:name] == :ec2
      raise PluginValidationError, "You selected #{@plugin_config['availability_zone']} availability zone, but your instance is running in #{@current_availability_zone} zone. Please change availability zone in plugin configuration file to #{@current_availability_zone} (see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#EBS_Delivery_Plugin) or use another instance in #{@plugin_config['availability_zone']} zone to create your EBS AMI." if @plugin_config['availability_zone'] != @current_availability_zone

      @plugin_config['account_number'].to_s.gsub!(/-/, '')

      AWS.config(:access_key_id => @plugin_config['access_key'],
        :secret_access_key => @plugin_config['secret_access_key'],
        :ec2_endpoint => @ec2_endpoints[@current_region][:endpoint],
        :max_retries => 5,
        :use_ssl => @plugin_config['use_ssl'])

      @ec2 = AWS::EC2.new
      @ec2helper = EC2Helper.new(@ec2, :log => @log)
    end

    def after_init
      register_supported_os('fedora', ['13', '14', '15'])
      register_supported_os('rhel', ['6'])
      register_supported_os('centos', ['5'])
    end

    def execute
      ebs_appliance_description = "#{@appliance_config.summary} | Appliance version #{@appliance_config.version}.#{@appliance_config.release} | #{@appliance_config.hardware.arch} architecture"

      @log.debug "Checking if appliance is already registered..."
      ami = @ec2helper.ami_by_name(ebs_appliance_name)

      if ami and @plugin_config['overwrite']
        @log.info "Overwrite is enabled. Stomping existing assets."
        stomp_ebs(ami)
      elsif ami
        @log.warn "EBS AMI '#{ami.name}' is already registered as '#{ami.id}' (region: #{@current_region})."
        return
      end

      @log.info "Creating new EBS volume..."
      size = 0
      @appliance_config.hardware.partitions.each_value { |partition| size += partition['size'] }

      # create_volume, ceiling to avoid non-Integer values as per https://issues.jboss.org/browse/BGBUILD-224
      volume = @ec2.volumes.create(:size => size.ceil.to_i, :availability_zone => @plugin_config['availability_zone'])

      @log.debug "Volume #{volume.id} created."
      @log.debug "Waiting for EBS volume #{volume.id} to be available..."

      # wait for volume to be created
      @ec2helper.wait_for_volume_status(:available, volume)

      # get first free device to mount the volume
      suffix = free_device_suffix
      device_name = "/dev/sd#{suffix}"
      @log.trace "Got free device suffix: '#{suffix}'"

      @log.trace "Reading current instance id..."
      # get_current_instance
      current_instance = @ec2.instances[@current_instance_id]

      @log.trace "Got: #{current_instance.id}"
      @log.info "Attaching created volume..."
      # attach the volume to current host
      volume.attach_to(current_instance, device_name)

      @log.debug "Waiting for EBS volume to be attached..."
      # wait for volume to be attached
      @ec2helper.wait_for_volume_status(:in_use, volume)

      @log.debug "Waiting for the attached EBS volume to be discovered by the OS"
      wait_for_volume_attachment(suffix)

      @log.info "Copying data to EBS volume..."

      @image_helper.customize([@previous_deliverables.disk, device_for_suffix(suffix)], :automount => false) do |guestfs, guestfs_helper|
        @image_helper.sync_filesystem(guestfs, guestfs_helper)

        @log.debug "Adjusting /etc/fstab..."
        adjust_fstab(guestfs)
      end

      @log.debug "Detaching EBS volume..."
      volume.attachments.map(&:delete)

      @log.debug "Waiting for EBS volume to become available..."
      @ec2helper.wait_for_volume_status(:available, volume)

      @log.info "Creating snapshot from EBS volume..."
      snapshot = @ec2.snapshots.create(
          :volume => volume,
          :description => ebs_appliance_description)

      @log.debug "Waiting for snapshot #{snapshot.id} to be completed..."
      @ec2helper.wait_for_snapshot_status(:completed, snapshot)

      @log.debug "Deleting temporary EBS volume..."
      volume.delete

      @log.info "Registering image..."
      image = @ec2.images.create(
          :name => ebs_appliance_name,
          :root_device_name => ROOT_DEVICE_NAME,
          :block_device_mappings => { ROOT_DEVICE_NAME => {
                                      :snapshot => snapshot,
                                      :delete_on_termination => @plugin_config['delete_on_termination']
                                    },
                                    '/dev/sdb' => 'ephemeral0',
                                    '/dev/sdc' => 'ephemeral1',
                                    '/dev/sdd' => 'ephemeral2',
                                    '/dev/sde' => 'ephemeral3'},
          :architecture => @appliance_config.hardware.base_arch,
          :kernel_id => @ec2_endpoints[@current_region][:kernel][@appliance_config.hardware.base_arch.intern][:aki],
          :description => ebs_appliance_description)

      @log.info "Waiting for the new EBS AMI to become available"
      @ec2helper.wait_for_image_state(:available, image)
      @log.info "EBS AMI '#{image.name}' registered: #{image.id} (region: #{@current_region})"
    rescue Timeout::Error
      @log.error "An operation timed out. Manual intervention may be necessary to complete the task."
      raise
    end

    def ami_by_name(name)
      @ec2helper.ami_by_name(name, @plugin_config['account_number'])
    end

    alias :already_registered? :ami_by_name

    def terminate_instances(instances)
      instances.map(&:terminate)
      instances.each do |i|
        @ec2helper.wait_for_instance_death(i)
      end
    end

    def stomp_ebs(ami)
      #Find any instances that are running, if they are not stopped then abort.
      if live = @ec2helper.live_instances(ami)
        if @plugin_config['terminate_instances']
          @log.info "Terminating the following instances: #{live.collect{|i| "#{i.id} (#{i.status})"}.join(", ")}."
          terminate_instances(live)
        else
          raise "There are still instances of #{ami.id} running, you should terminate them after " <<
               "preserving any important data: #{live.collect{|i| "#{i.id} (#{i.status})"}.join(", ")}."
        end
      end

      @log.info("Finding the primary snapshot associated with #{ami.id}.")
      primary_snapshot = @ec2helper.snapshot_by_id(ami.block_device_mappings[ami.root_device_name].snapshot_id)

      @log.info("De-registering the EBS AMI.")
      ami.deregister
      @ec2helper.wait_for_image_death(ami)

      if !@plugin_config['preserve_snapshots'] and primary_snapshot
        @log.info("Deleting the primary snapshot.")
        primary_snapshot.delete
      end
    end

    def ebs_appliance_name
      base_path = "#{@appliance_config.name}/#{@appliance_config.os.name}/#{@appliance_config.os.version}/#{@appliance_config.version}.#{@appliance_config.release}"

      return "#{base_path}/#{@appliance_config.hardware.arch}" unless @plugin_config['snapshot']

      snapshot = 1

      while @ec2helper.already_registered?("#{base_path}-SNAPSHOT-#{snapshot}/#{@appliance_config.hardware.arch}")
        snapshot += 1
      end
      # Reuse the last key (if there was one)
      snapshot -=1 if snapshot > 1 and @plugin_config['overwrite']

      "#{base_path}-SNAPSHOT-#{snapshot}/#{@appliance_config.hardware.arch}"
    end

    def adjust_fstab(guestfs)
      guestfs.sh("cat /etc/fstab | grep -v '/mnt' | grep -v '/data' | grep -v 'swap' > /etc/fstab.new")
      guestfs.mv("/etc/fstab.new", "/etc/fstab")
    end

    def wait_for_volume_attachment(suffix)
      @ec2helper.wait_with_timeout(POLL_FREQ, TIMEOUT){ device_for_suffix(suffix) != nil }
    end

    def device_for_suffix(suffix)
      return "/dev/sd#{suffix}" if File.exists?("/dev/sd#{suffix}")
      return "/dev/xvd#{suffix}" if File.exists?("/dev/xvd#{suffix}")
      nil
    end

    def free_device_suffix
      ("f".."p").each do |suffix|
        return suffix unless File.exists?("/dev/sd#{suffix}") or File.exists?("/dev/xvd#{suffix}")
      end
      raise "Found too many attached devices. Cannot attach EBS volume."
    end

    def valid_platform?
      begin
        region = EC2Helper::availability_zone_to_region(EC2Helper::current_availability_zone)
        return true if @ec2_endpoints.has_key? region
        @log.warn "You may be using an ec2 region that BoxGrinder Build is not aware of: #{region}, BoxGrinder Build knows of: #{@ec2_endpoints.join(", ")}"
      rescue Net::HTTPServerException => e
        @log.warn "An error was returned when attempting to retrieve the ec2 hostname: #{e.to_s}"
      rescue Timeout::Error => t
        @log.warn "A timeout occurred while attempting to retrieve the ec2 hostname: #{t.to_s}"
      end
      false
    end

  end
end

plugin :class => BoxGrinder::EBSPlugin, :type => :delivery, :name => :ebs, :full_name => "Elastic Block Storage"