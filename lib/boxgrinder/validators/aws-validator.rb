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

require 'boxgrinder/validators/errors'

module BoxGrinder
  class AWSValidator

    def initialize( config )
      @config = config
    end

    def validate_aws_config( config )
      secure_permissions  = "600"

      raise ValidationError, "Please specify aws section in configuration file (#{@config.config_file}). #{DEFAULT_HELP_TEXT[:general]}" if config.nil?

      raise ValidationError, "Please specify path to cert in aws section in configuration file (#{@config.config_file}). #{DEFAULT_HELP_TEXT[:general]}" if config['cert_file'].nil?
      raise ValidationError, "Certificate file '#{config['cert_file']}' specified in configuration file (#{@config.config_file}) doesn't exists. Please check your path. #{DEFAULT_HELP_TEXT[:general]}" unless File.exists?( config['cert_file'] )
      cert_permission = sprintf( "%o", File.stat( config['cert_file'] ).mode )[ 3, 5 ]
      raise ValidationError, "Certificate file '#{config['cert_file']}' specified in aws section in configuration file (#{@config.config_file}) has wrong permissions (#{cert_permission}), please correct it, run: 'chmod #{secure_permissions} #{config['cert_file']}'." unless cert_permission.eql?( secure_permissions )

      raise ValidationError, "Please specify path to private key in aws section in configuration file (#{@config.config_file}). #{DEFAULT_HELP_TEXT[:general]}" if config['key_file'].nil?
      raise ValidationError, "Private key file '#{config['key_file']}' specified in aws section in configuration file (#{@config.config_file}) doesn't exists. Please check your path." unless File.exists?( config['key_file'] )
      key_permission = sprintf( "%o", File.stat( config['key_file'] ).mode )[ 3, 5 ]
      raise ValidationError, "Private key file '#{config['key_file']}' specified in aws section in configuration file (#{@config.config_file}) has wrong permissions (#{key_permission}), please correct it, run: 'chmod #{secure_permissions} #{config['key_file']}'." unless key_permission.eql?( secure_permissions )

      raise ValidationError, "Please specify account number in aws section in configuration file (#{@config.config_file}). #{DEFAULT_HELP_TEXT[:general]}" if config['account_number'].nil?
      raise ValidationError, "Please specify access key in aws section in configuration file (#{@config.config_file}). #{DEFAULT_HELP_TEXT[:general]}" if config['access_key'].nil?
      raise ValidationError, "Please specify secret access key in aws section in configuration file (#{@config.config_file}). #{DEFAULT_HELP_TEXT[:general]}" if config['secret_access_key'].nil?
    end

    # TODO we're using this?
    def validate_aws_release_config( config )
      return if config.nil?

      raise ValidationError, "No 's3' subsection in 'release' section in configuration file (#{@config.config_file})." if config['s3'].nil?
      raise ValidationError, "Please specify bucket name in 's3' subsection in configuration file (#{@config.config_file})." if config['s3']['bucket_name'].nil? or config['s3']['bucket_name'].length == 0
    end
  end
end