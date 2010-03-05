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

module BoxGrinder
  class SSHValidator
    def initialize( config )
      @config = config
    end

    def validate
      raise ValidationError, "Specified configuration file (#{@config.config_file}) doesn't exists. #{DEFAULT_HELP_TEXT[:general]}" unless File.exists?( @config.config_file )
      raise ValidationError, "No 'ssh' section in config file in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if @config.data['ssh'].nil?
      raise ValidationError, "Host not specified in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if @config.data['ssh']['host'].nil?
      raise ValidationError, "Username not specified in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if @config.data['ssh']['username'].nil?
      raise ValidationError, "Remote release packages path (remote_release_path) not specified in ssh section in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if @config.data['ssh']['remote_rpm_path'].nil?
    end
  end
end