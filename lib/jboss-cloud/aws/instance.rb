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

require 'rake'
require 'rake/tasklib'
require 'jboss-cloud/aws/aws-support'
require 'yaml'
require 'base64'
require 'fileutils'

module JBossCloud
  class AWSInstance < Rake::TaskLib
    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config
      @instances_dir     = "#{ENV['HOME']}/.jboss-cloud/instances"
      @ec2_run_file      = "#{@instances_dir}/#{@appliance_config.name}.run"

      define_tasks
    end

    def define_tasks

      directory @instances_dir

      desc "Run #{@appliance_config.simple_name} appliance on Amazon EC2."
      task "appliance:#{@appliance_config.name}:ec2:run" => [ "appliance:#{@appliance_config.name}:ec2:register", @instances_dir ] do
        @aws_support = AWSSupport.new( @config )
        run_instance
      end

      desc "Terminate running #{@appliance_config.simple_name} appliance on Amazon EC2."
      task "appliance:#{@appliance_config.name}:ec2:terminate" => [ @instances_dir ] do
        @aws_support = AWSSupport.new( @config )
        terminate_instance
      end
    end

    def run_instance
      instance_type   = @appliance_config.is64bit? ? "m1.large" : "m1.small"
      image_id        = @aws_support.ami_info( @appliance_config.name ).imageId
      user_data       = @appliance_config.name.eql?( "management-appliance" ) ? Base64.encode64( { "access_key" => @aws_support.aws_data['access_key'], "secret_access_key" => @aws_support.aws_data['secret_access_key'] }.to_yaml ) : nil

      response = @aws_support.ec2.run_instances( :image_id => image_id, :instance_type => instance_type, :user_data => user_data )

      ami_info = response.instancesSet.item[0]

      File.open( @ec2_run_file, "w") {|f| f.write( ami_info.to_yaml ) }

      puts "One instance of #{@appliance_config.simple_name} appliance is launched, instance ID: #{ami_info.instanceId} "
    end

    def terminate_instance
      if !File.exist?( @ec2_run_file )
        puts "No instances of #{@appliance_config.simple_name} appliance were launched."
        return
      end

      ami_info = YAML.load_file(  @ec2_run_file )

      begin
        instances = @aws_support.ec2.describe_instances( :instance_id => ami_info.instanceId  )
      rescue
        puts "No running instances of #{@appliance_config.simple_name} appliance with ID = #{ami_info.instanceId}."
        FileUtils.rm( @ec2_run_file )
        return
      end

      for reservation in instances.reservationSet.item
        for instance in reservation.instancesSet.item
          response = @aws_support.ec2.terminate_instances( :instance_id => instance.instanceId )

          puts "Instance of #{@appliance_config.simple_name} appliance with ID = #{instance.instanceId} is shutting down."
        end
      end

      FileUtils.rm( @ec2_run_file )

    end
  end
end
