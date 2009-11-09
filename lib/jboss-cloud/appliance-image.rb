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

    def initialize( config, appliance_config, options = {} )
      @config                  = config
      @appliance_config        = appliance_config

      @log          = options[:log]         || LOG
      @exec_helper  = options[:exec_helper] || EXEC_HELPER

      @appliance_build_dir     = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @raw_disk                = "#{@appliance_build_dir}/#{@appliance_config.name}-sda.raw"
      @kickstart_file          = "#{@appliance_build_dir}/#{@appliance_config.name}.ks"
      @tmp_dir                 = "#{@config.dir_root}/#{@config.dir_build}/tmp"
      @xml_file                = "#{@appliance_build_dir}/#{@appliance_config.name}.xml"

      ApplianceVMXImage.new( @config, @appliance_config )
      #ApplianceEC2Image.new( @config, @appliance_config )
      #AWSInstance.new( @config, @appliance_config )

      define_tasks
    end

    def define_tasks
      desc "Build #{@appliance_config.simple_name} appliance."
      task "appliance:#{@appliance_config.name}" => [ @xml_file, "appliance:#{@appliance_config.name}:validate:dependencies" ]

      directory @tmp_dir

      file @xml_file => [ @kickstart_file, "appliance:#{@appliance_config.name}:validate:dependencies", @tmp_dir ] do
        build_raw_image
        do_post_build_operations
      end
    end

    def build_raw_image
      @log.info "Building #{@appliance_config.simple_name} appliance..."

      @exec_helper.execute "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{@tmp_dir} --cache=#{@config.dir.rpms_cache}/#{@appliance_config.main_path} --config #{@kickstart_file} -o #{@config.dir.build}/appliances/#{@appliance_config.main_path} --name #{@appliance_config.name} --vmem #{@appliance_config.hardware.memory} --vcpu #{@appliance_config.hardware.cpus}"

      # fix permissions
      @exec_helper.execute "sudo chmod 666 #{@raw_disk}"
      @exec_helper.execute "sudo chmod 666 #{@xml_file}"

      @log.info "Appliance #{@appliance_config.simple_name} was built successfully."
    end

    def do_post_build_operations
      @log.info "Executing post operations after build..."

      guestfs_helper  = GuestFSHelper.new( @raw_disk )
      guestfs         = guestfs_helper.guestfs

      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # don't use DNS for SSH
      guestfs.aug_set( "/files/etc/ssh/sshd_config/UseDNS", "no" )
      guestfs.aug_save
      @log.debug "Augeas changes saved."

      @log.debug "Setting up '/etc/motd'..."
      # set nice banner for SSH
      motd_file = "/etc/init.d/motd"
      guestfs.upload( "#{@config.dir.base}/src/motd.init", motd_file )
      guestfs.sh( "sed -i s/#NAME#/'#{@config.name}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#VERSION#/'#{@config.version_with_release}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#APPLIANCE#/'#{@appliance_config.simple_name} appliance'/ #{motd_file}" )

      guestfs.sh( "/bin/chmod +x #{motd_file}" )
      guestfs.sh( "/sbin/chkconfig --add motd" )
      @log.debug "'/etc/motd' is nice now."

      # before we access RPM database we need to clean it...
      #guestfs_helper.rebuild_rpm_database

      guestfs.close

      @log.info "Post operations executed."
    end
  end
end
