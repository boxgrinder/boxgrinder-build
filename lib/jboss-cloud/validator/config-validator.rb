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

require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'

module JBossCloud
  class ConfigValidator
    def validate( config )
      @config = config
      
      validate_base_pkgs
    end
    
    def validate_base_pkgs
      base_pkgs_suffix = "#{@config.os_name}/#{@config.os_version}/base-pkgs.ks"
      
      if File.exists?( "#{@config.dir.kickstarts}/#{base_pkgs_suffix}" )
        @config.files.base_pkgs = base_pkgs
      else
        @config.files.base_pkgs = "#{@config.dir.base}/kickstarts/#{base_pkgs_suffix}"
      end
      
      raise ValidationError, "base-pkgs.ks file doesn't exists for your OS (#{@config.os_name} #{@config.os_version})" unless File.exists?( @config.files.base_pkgs )
    end
  end
end
