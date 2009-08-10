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
      ApplianceEC2Image.new( @config, @appliance_config )
      AWSInstance.new( @config, @appliance_config )

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
        do_post_build_operations
      end
    end

    def build_raw_image
      @log.info "Building #{@appliance_config.simple_name} appliance..."

      @exec_helper.execute "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{@tmp_dir} --cache=#{@config.dir_rpms_cache}/#{@appliance_config.main_path} --config #{@kickstart_file} -o #{@config.dir_build}/appliances/#{@appliance_config.main_path} --name #{@appliance_config.name} --vmem #{@appliance_config.mem_size} --vcpu #{@appliance_config.vcpu}"

      # fix permissions
      @exec_helper.execute "sudo chmod 666 #{@raw_disk}"
      @exec_helper.execute "sudo chmod 666 #{@xml_file}"

      @log.info "Appliance #{@appliance_config.simple_name} was built successfully."
    end

    def do_post_build_operations
      @log.info "Executing post operations after build..."

      guestfs = GuestFSHelper.new( @raw_disk ).guestfs

      guestfs.aug_init( "/", 0 )

      # don't use DNS for SSH
      guestfs.aug_set( "/files/etc/ssh/sshd_config/UseDNS", "no" )

      guestfs.aug_save

      # set nice banner for SSH
      motd_file = "/etc/init.d/motd"
      guestfs.upload( "#{@config.dir.base}/src/motd.init", motd_file )
      guestfs.sh( "sed -i s/#NAME#/'#{@config.name}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#VERSION#/'#{@config.version_with_release}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#APPLIANCE#/'#{@appliance_config.simple_name} appliance'/ #{motd_file}" )

      guestfs.sh( "/bin/chmod +x #{motd_file}" )
      guestfs.sh( "/sbin/chkconfig --add motd" )

      # before we install anything we need to clean up RPM database...
      cleanup_rpm_database( guestfs )

      # TODO remove this, http://oddthesis.lighthouseapp.com/projects/19748-jboss-cloud/tickets/95
      if guestfs.sh( "rpm -qa | grep httpd | wc -l" ).to_i > 0
        @log.debug "Applying APR/HTTPD workaround..."
        guestfs.sh( "yum -y remove apr" )
        guestfs.sh( "yum -y install mod_cluster --disablerepo=updates" )
        guestfs.sh( "/sbin/chkconfig httpd on" )
        @log.debug "Workaround applied."

        # clean RPM database one more time to leave image clean
        cleanup_rpm_database( guestfs )
      end

      guestfs.close

      @log.info "Post operations executed."
    end

    def cleanup_rpm_database( guestfs )
      # TODO this is shitty, I know... https://bugzilla.redhat.com/show_bug.cgi?id=507188
      guestfs.sh( "rm /var/lib/rpm/__db.*" )

      @log.debug "Cleaning RPM database..."
      guestfs.sh( "rpm --rebuilddb" )
      @log.debug "Cleaning RPM database finished."
    end
  end
end
