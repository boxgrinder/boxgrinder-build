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
require 'jboss-cloud/appliance-vmx-image'
require 'jboss-cloud/appliance-ec2-image'
require 'yaml'
require 'jboss-cloud/aws/instance'
require 'jboss-cloud/appliance-image-customize'
require 'jboss-cloud/helpers/guestfs-helper'

module JBossCloud
  class ApplianceImage < Rake::TaskLib

    def initialize( config, appliance_config )
      @config                  = config
      @appliance_config        = appliance_config

      @appliance_build_dir     = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @raw_disk                = "#{@appliance_build_dir}/#{@appliance_config.name}-sda.raw"
      @kickstart_file          = "#{@appliance_build_dir}/#{@appliance_config.name}.ks"
      @tmp_dir                 = "#{@config.dir_root}/#{@config.dir_build}/tmp"
      @xml_file                = "#{@appliance_build_dir}/#{@appliance_config.name}.xml"

      define_tasks
    end

    def define_tasks
      desc "Build #{@appliance_config.simple_name} appliance."
      task "appliance:#{@appliance_config.name}" => [ @xml_file, "appliance:#{@appliance_config.name}:validate:dependencies" ]

      directory @tmp_dir

      for appliance_name in @appliance_config.appliances
        task "appliance:#{@appliance_config.name}:rpms" => [ "rpm:#{appliance_name}" ]
      end

      file @xml_file => [ @kickstart_file, "appliance:#{@appliance_config.name}:validate:dependencies", @tmp_dir ] do
        build_raw_image
        cleanup_rpm_database
      end

      ApplianceVMXImage.new( @config, @appliance_config )
      ApplianceEC2Image.new( @config, @appliance_config )
      AWSInstance.new( @config, @appliance_config )
    end


    def build_raw_image
      command = "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{@tmp_dir} --cache=#{@config.dir_rpms_cache}/#{@appliance_config.main_path} --config #{@kickstart_file} -o #{@config.dir_build}/appliances/#{@appliance_config.main_path} --name #{@appliance_config.name} --vmem #{@appliance_config.mem_size} --vcpu #{@appliance_config.vcpu}"
      execute_command( command )

      # fix permissions
      `sudo chown oddthesis:oddthesis #{@raw_disk}`
    end

    def cleanup_rpm_database
      guesfs_helper = GuestFSHelper.new( @raw_disk )

      # TODO this is shitty, I know... https://bugzilla.redhat.com/show_bug.cgi?id=507188
      for i in (1..9)
        guesfs_helper.guestfs.rm_rf( "/var/lib/rpm/__db.00#{i.to_s}" )
      end

      guesfs_helper.guestfs.command( ["rpm", "--rebuilddb"] )
    end
  end
end
