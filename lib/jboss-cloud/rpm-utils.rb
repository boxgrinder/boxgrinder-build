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
require 'net/ssh'
require 'net/sftp'
require 'jboss-cloud/validator/errors'
require 'jboss-cloud/ssh/ssh-config'
require 'jboss-cloud/helpers/ssh-helper'

module JBossCloud
  class RPMUtils < Rake::TaskLib

    def initialize( config )
      @config = config

      @arches = SUPPORTED_ARCHES + [ "noarch" ]
      @oses   = SUPPORTED_OSES

      define_tasks
    end

    def define_tasks
      desc "Upload all packages."
      task 'rpm:upload:all' => [ 'rpm:sign:all' ] do
        prepare_file_list
      end
    end

    def validate_rpm_upload_config( ssh_config )
      raise ValidationError, "Remote packages path (remote_rpm_path) not specified in ssh section in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if ssh_config.cfg['remote_rpm_path'].nil?
    end

    def upload_packages
      ssh_config = SSHConfig.new( @config )

      validate_rpm_upload_config( ssh_config )

      dirs = []
      packages = {}

      for os in @oses.keys
        for version in @oses[os]
          for arch in @arches
            dirs.push( "#{os}/#{version}/RPMS/#{arch}" )
            Dir[ "#{@config.dir.top}/#{os}/#{version}/RPMS/#{arch}/*.rpm" ].each do |file|
              local_prefix_length = "#{@config.dir.top}/".length
              packages[file[ local_prefix_length, file.length ]] = file
            end
          end
        end
      end

      Dir[ "#{@config.dir.top}/#{APPLIANCE_DEFAULTS['os_name']}/#{APPLIANCE_DEFAULTS['os_version']}/SRPMS/*.src.rpm" ].each do |file|
        local_prefix_length = "#{@config.dir.top}/#{APPLIANCE_DEFAULTS['os_name']}/#{APPLIANCE_DEFAULTS['os_version']}/".length
        packages[file[ local_prefix_length, file.length ]] = file
      end

      dirs.push( "SRPMS" )

      ssh_helper = SSHHelper.new( ssh_config.options )

      ssh_helper.connect
      ssh_helper.upload_files( ssh_config.cfg['remote_rpm_path'], packages )
      ssh_helper.createrepo( ssh_config.cfg['remote_rpm_path'], dirs )
      ssh_helper.disconnect
    end

  end
end