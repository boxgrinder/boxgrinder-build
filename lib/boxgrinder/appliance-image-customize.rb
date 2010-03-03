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
require 'boxgrinder/validator/errors'
require 'boxgrinder/helpers/guestfs-helper'
require 'tempfile'

module BoxGrinder
  class ApplianceImageCustomize < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config = config
      @appliance_config = appliance_config

      @log          = options[:log]         || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new( { :log => @log } )
    end

    def validate_options( options )
      options = {
              :packages => {},
              :repos => []
      }.merge(options)

      options[:packages][:yum] = options[:packages][:yum] || []
      options[:packages][:yum_local] = options[:packages][:yum_local] || []
      options[:packages][:rpm] = options[:packages][:rpm] || []

      if ( options[:packages][:yum_local].size == 0 and options[:packages][:rpm].size == 0 and options[:packages][:yum].size == 0 and options[:repos].size == 0)
        @log.debug "No additional local or remote packages or gems to install, skipping..."
        return false
      end

      true
    end

    def customize( raw_file, options = {} )
      # silent return, we don't have any packages to install
      return unless validate_options( options )

      raise ValidationError, "Raw file '#{raw_file}' doesn't exists, please specify valid raw file" if !File.exists?( raw_file )

      guestfs_helper = GuestFSHelper.new( raw_file )
      guestfs = guestfs_helper.guestfs

      guestfs_helper.rebuild_rpm_database

      for repo in options[:repos]
        @log.debug "Installing repo file '#{repo}'..."
        guestfs.sh( "rpm -Uvh #{repo}" )
        @log.debug "Repo file '#{repo}' installed."
      end unless options[:repos].nil?

      unless options[:packages].nil?
        for yum_package in options[:packages][:yum]
          @log.debug "Installing package '#{yum_package}'..."
          guestfs.sh( "yum -y install #{yum_package}" )
          @log.debug "Package '#{yum_package}' installed."
        end unless options[:packages][:yum].nil?

        for package in options[:packages][:rpm]
          @log.debug "Installing package '#{package}'..."
          guestfs.sh( "rpm -Uvh --force #{package}" )
          @log.debug "Package '#{package}' installed."
        end unless options[:packages][:rpm].nil?
      end

      guestfs.close
    end
  end
end
