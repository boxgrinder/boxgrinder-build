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
require 'boxgrinder/appliance-vmx-image'
require 'boxgrinder/appliance-ec2-image'
require 'yaml'
require 'boxgrinder/aws/instance'
require 'boxgrinder/appliance-image-customize'
require 'boxgrinder/helpers/guestfs-helper'

module BoxGrinder
  class ApplianceImage < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config = config
      @appliance_config = appliance_config

      @log = options[:log] || LOG
      @exec_helper = options[:exec_helper] || EXEC_HELPER

      @tmp_dir = "#{@config.dir.root}/#{@config.dir.build}/tmp"

      ApplianceVMXImage.new( @config, @appliance_config )
      ApplianceEC2Image.new( @config, @appliance_config )
      #AWSInstance.new( @config, @appliance_config )

      define_tasks
    end

    def define_tasks
      desc "Build #{@appliance_config.simple_name} appliance."
      task "appliance:#{@appliance_config.name}" => [ @appliance_config.path.file.raw.xml, "appliance:#{@appliance_config.name}:validate:dependencies" ]

      directory @tmp_dir

      file @appliance_config.path.file.raw.xml => [ @appliance_config.path.file.raw.kickstart, "appliance:#{@appliance_config.name}:validate:dependencies", @tmp_dir ] do
        build_raw_image
        do_post_build_operations
      end
    end

    def build_raw_image
      @log.info "Building #{@appliance_config.simple_name} appliance..."

      @exec_helper.execute "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{@tmp_dir} --cache=#{@config.dir.rpms_cache}/#{@appliance_config.main_path} --config #{@appliance_config.path.file.raw.kickstart} -o #{@appliance_config.path.dir.raw.build} --name #{@appliance_config.name} --vmem #{@appliance_config.hardware.memory} --vcpu #{@appliance_config.hardware.cpus}"

      # fix permissions
      @exec_helper.execute "sudo chmod 777 #{@appliance_config.path.dir.raw.build_full}"
      @exec_helper.execute "sudo chmod 666 #{@appliance_config.path.file.raw.disk}"
      @exec_helper.execute "sudo chmod 666 #{@appliance_config.path.file.raw.xml}"

      @log.info "Appliance #{@appliance_config.simple_name} was built successfully."
    end

    def do_post_build_operations
      @log.info "Executing post operations after build..."

      guestfs_helper = GuestFSHelper.new( @appliance_config.path.file.raw.disk )
      guestfs = guestfs_helper.guestfs

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
      guestfs.sh( "sed -i s/#VERSION#/'#{@appliance_config.version}.#{@appliance_config.release}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#APPLIANCE#/'#{@appliance_config.name} appliance'/ #{motd_file}" )

      guestfs.sh( "/bin/chmod +x #{motd_file}" )
      guestfs.sh( "/sbin/chkconfig --add motd" )
      @log.debug "'/etc/motd' is nice now."

      oddthesis_repo_file = "/etc/yum.repos.d/oddthesis.repo"
      oddthesis_gpg_key_file = "/etc/pki/rpm-gpg/RPM-GPG-KEY-oddthesis"

      @log.debug "Installing oddthesis repository and GPG keys..."
      guestfs.upload( "#{@config.dir.base}/src/oddthesis/oddthesis.repo", oddthesis_repo_file )
      guestfs.sh( "sed -i s/#OS_NAME#/'#{@appliance_config.os.name}'/ #{oddthesis_repo_file}" )
      guestfs.sh( "sed -i s/#OS_VERSION#/'#{@appliance_config.os.version}'/ #{oddthesis_repo_file}" )
      guestfs.upload( "#{@config.dir.base}/src/oddthesis/RPM-GPG-KEY-oddthesis", oddthesis_gpg_key_file )
      @log.debug "Repository installed."

      @log.debug "Installing BoxGrinder version files..."
      guestfs.sh( "echo 'BOXGRINDER_VERSION=#{@config.version_with_release}' > /etc/sysconfig/boxgrinder" )
      guestfs.sh( "echo 'APPLIANCE_NAME=#{@appliance_config.name}' >> /etc/sysconfig/boxgrinder" )
      guestfs.sh( "echo '#{{ "appliance_name" => @appliance_config.name}.to_yaml}' > /etc/boxgrinder" )
      @log.debug "Version files installed."

      # TODO: remove after https://bugzilla.redhat.com/show_bug.cgi?id=551469 is fixed
      @log.debug "Fixing appliance-creator bug: https://bugzilla.redhat.com/show_bug.cgi?id=551469"
      initrd = `ls /boot/initramfs* 2> /dev/null | wc -l`.to_i > 0 ? "initrams" : "initrd"
      guestfs.sh( "sed s/'initrd \\/boot\\/initrd'/'initrd \\/boot\\/#{initrd}'/ /boot/grub/grub.conf" )
      @log.debug "Hack applied."

      @log.debug "Executing post commands..."
      for cmd in @appliance_config.post.base
        @log.debug "Executing #{cmd}"
        guestfs.sh( cmd )
      end
      @log.debug "Post commands executed."

      guestfs.close

      @log.info "Post operations executed."
    end
  end
end
