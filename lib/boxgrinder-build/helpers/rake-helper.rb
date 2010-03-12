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

require 'rubygems'
require 'boxgrinder-build/boxgrinder'
require 'boxgrinder-core/helpers/log-helper'

gem 'amazon-ec2', '>= 0.9.6'
gem 'aws-s3', '>= 0.6.2'
gem 'net-sftp', '>= 2.0.4'
gem 'net-ssh', '>= 2.0.20'

module Rake
  class Task
    alias_method :execute_original_boxgrinder, :execute

    def execute( args = nil )
      begin
        execute_original_boxgrinder( args )
      rescue => e
        log = BoxGrinder::LOG
        log.fatal e.info
        log.fatal "Aborting: #{e.message}. See previous errors for more information."
        abort
      end
    end
  end
end

module BoxGrinder

  LOG = LogHelper.new

  class RakeHelper
    def initialize( project_config = {} )
      log = LOG
      begin
        log.debug "Running new Rake session..."
        @config = BoxGrinder.new( project_config ).config
      rescue ValidationError => e
        log.fatal "ValidationError: #{e.message}."
        abort
      rescue => e
        log.fatal e
        log.fatal "Aborting: #{e.message}. See previous errors for more information."
        abort
      end
    end

    attr_reader :config
  end
end


