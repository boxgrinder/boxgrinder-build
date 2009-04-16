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

require 'jboss-cloud/validator/errors'
require 'yaml'

module JBossCloud
  class SSHConfig
    def initialize( cfg_file )
      @cfg_file = cfg_file
      @options = {}

      # defaults
      @options['sftp_create_path']          = true
      @options['sftp_overwrite']            = false
      @options['sftp_default_permissions']  = 0644

      validate
    end

    def validate
      more_info = "See http://oddthesis.org/ for more info."

      raise ValidationError, "Specified configuration file (#{@cfg_file}) doesn't exists. #{more_info}" unless File.exists?( @cfg_file )

      # we need only ssh section
      @cfg = YAML.load_file( @cfg_file )['ssh']

      raise ValidationError, "Host not specified in configuration file '#{@cfg_file}'. #{more_info}" if @cfg['host'].nil?
      raise ValidationError, "Username not specified in configuration file '#{@cfg_file}'. #{more_info}" if @cfg['username'].nil?

      @options['host']      = @cfg['host']
      @options['username']  = @cfg['username']
      @options['password']  = @cfg['password']
    end

    attr_reader :options
    attr_reader :cfg
  end
end