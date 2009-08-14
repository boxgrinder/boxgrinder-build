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
require 'jboss-cloud/validator/errors'
require 'jboss-cloud/ssh/ssh-config'
require 'jboss-cloud/helpers/ssh-helper'

module JBossCloud
  class ApplianceUtils < Rake::TaskLib
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config

      @package_dir                  = "#{@config.dir.build}/appliances/#{@config.build_path}/packages/#{@config.arch}"
      @package_raw                  = "#{@package_dir}/#{@appliance_config.name}-#{@config.version_with_release}-#{@config.arch}-raw.tar.gz"
      @package_vmware_enterprise    = "#{@package_dir}/#{@appliance_config.name}-#{@config.version_with_release}-#{@config.arch}-VMware-enterprise.tar.gz"
      @package_vmware_personal      = "#{@package_dir}/#{@appliance_config.name}-#{@config.version_with_release}-#{@config.arch}-VMware-personal.tar.gz"

      @appliance_raw_dir                   = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @appliance_vmware_personal_dir       = "#{@config.dir_build}/#{@appliance_config.appliance_path}/vmware/personal"
      @appliance_vmware_enterprise_dir     = "#{@config.dir_build}/#{@appliance_config.appliance_path}/vmware/enterprise"

      @exec_helper       = EXEC_HELPER
      @log               = LOG

      define_tasks
    end

    def define_tasks

      directory @package_dir

      #desc "Upload #{@appliance_config.simple_name} appliance package to server"
      task "appliance:#{@appliance_config.name}:upload" => [ "appliance:#{@appliance_config.name}:package" ] do
        upload_packages
      end

      task "appliance:#{@appliance_config.name}:package" => [ @package_raw, @package_vmware_enterprise, @package_vmware_personal ]

      desc "Create RAW package for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:package:raw" => [ @package_raw ]

      desc "Create VMware Enterprise package for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:package:vmware:enterprise" => [ @package_vmware_enterprise ]

      desc "Create Vmware Personal package for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:package:vmware:personal" => [ @package_vmware_personal ]

      file @package_raw => [ @package_dir, "appliance:#{@appliance_config.name}" ] do
        @log.info "Packaging #{@appliance_config.simple_name} appliance RAW image (#{@config.os_name} #{@config.os_version}, #{@config.arch} arch)..."
        @exec_helper.execute "tar -C #{@appliance_raw_dir} -cvzf #{@package_raw} #{@appliance_config.name}-sda.raw #{@appliance_config.name}.xml"
      end

      vmware_files = "#{@appliance_config.name}-sda.raw #{@appliance_config.name}.vmx #{@appliance_config.name}.vmdk"

      file @package_vmware_enterprise => [ @package_dir, "appliance:#{@appliance_config.name}:vmware:enterprise" ] do
        @log.info "Packaging #{@appliance_config.simple_name} appliance VMware Enterprise image (#{@config.os_name} #{@config.os_version}, #{@config.arch} arch)..."
        @exec_helper.execute "tar -C #{@appliance_vmware_enterprise_dir} -cvzf '#{@package_vmware_enterprise}' #{vmware_files}"
      end

      file @package_vmware_personal => [ @package_dir, "appliance:#{@appliance_config.name}:vmware:personal" ] do
        @log.info "Packaging #{@appliance_config.simple_name} appliance VMware Personal image (#{@config.os_name} #{@config.os_version}, #{@config.arch} arch)..."
        @exec_helper.execute "tar -C #{@appliance_vmware_personal_dir} -cvzf #{@package_vmware_personal} #{vmware_files}"
      end
    end

    def validate_packages_upload_config( ssh_config )
      raise ValidationError, "Remote release packages path (remote_release_path) not specified in ssh section in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if ssh_config.cfg['remote_rpm_path'].nil?
    end

    def upload_packages
      ssh_config = SSHConfig.new( @config )

      validate_packages_upload_config( ssh_config )

      path = "#{@config.aws.bucket_prefix}/#{@appliance_config.arch}/#{@appliance_config.name}"

      raw_name                = File.basename( @package_raw )
      vmware_personal_name    = File.basename( @package_vmware_personal )
      vmware_enterprise_name  = File.basename( @package_vmware_enterprise )

      files = {}

      files["#{path}/#{raw_name}"]                = @package_raw
      files["#{path}/#{vmware_personal_name}"]    = @package_vmware_personal
      files["#{path}/#{vmware_enterprise_name}"]  = @package_vmware_enterprise

      @log.info "Uploading #{@appliance_config.name}..."
      ssh_helper = SSHHelper.new( ssh_config.options )
      ssh_helper.connect
      ssh_helper.upload_files( ssh_config.cfg['remote_release_path'], files )
      ssh_helper.disconnect
      @log.info "#{@appliance_config.name} uploaded."
    end
  end
end

desc "Upload all appliance packages to server"
task "appliance:upload:all"

