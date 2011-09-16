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
require 'net/ssh'
require 'net/sftp'
require 'progressbar'
require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-build/helpers/package-helper'
require 'boxgrinder-build/helpers/sftp-helper'

module BoxGrinder
  class SFTPPlugin < BasePlugin
    plugin :type => :delivery, :name => :sftp, :full_name  => "SSH File Transfer Protocol"

    def validate
      set_default_config_value('overwrite', false)
      set_default_config_value('default_permissions', 0644)
      set_default_config_value('identity', false)

      validate_plugin_config(['path', 'username', 'host'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#SFTP_Delivery_Plugin')

      @identity = (@plugin_config['identity'] || @plugin_config['i'])
      @sftp_helper = SFTPHelper.new(:log => @log)
    end

    def after_init
      register_deliverable(:package => "#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}-#{@appliance_config.os.name}-#{@appliance_config.os.version}-#{@appliance_config.hardware.arch}-#{current_platform}.tgz")
    end

    def execute
      PackageHelper.new(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).package( File.dirname(@previous_deliverables[:disk]), @deliverables[:package] )

      @log.info "Uploading #{@appliance_config.name} appliance via SSH..."

      sftp_opts={}
      sftp_opts.merge!(:password => @plugin_config['password']) if @plugin_config['password']
      sftp_opts.merge!(:keys => @identity.to_a) if @identity

      @sftp_helper.connect(@plugin_config['host'], @plugin_config['username'], sftp_opts)
      @sftp_helper.upload_files(@plugin_config['path'], @plugin_config['default_permissions'], @plugin_config['overwrite'], File.basename(@deliverables[:package]) => @deliverables[:package])

      @log.info "Appliance #{@appliance_config.name} uploaded."
    rescue => e
      @log.error e
      @log.error "An error occurred while uploading files."
      raise
    ensure
      @sftp_helper.disconnect
    end

  end
end

