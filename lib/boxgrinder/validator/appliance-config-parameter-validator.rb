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

require 'boxgrinder/config'
require 'boxgrinder/validator/errors'

module BoxGrinder
  class ApplianceConfigParameterValidator
    def validate
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_ARCH']}' is not a valid build architecture. Available architectures: #{SUPPORTED_ARCHES.join(", ")}." if (!ENV['JBOSS_CLOUD_ARCH'].nil? and !SUPPORTED_ARCHES.include?( ENV['JBOSS_CLOUD_ARCH']))
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_OS_NAME']}' is not a valid OS name. Please enter valid name." if !ENV['JBOSS_CLOUD_OS_NAME'].nil? && !SUPPORTED_OSES.keys.include?( ENV['JBOSS_CLOUD_OS_NAME'] )
      
      os_name = ENV['JBOSS_CLOUD_OS_NAME'].nil? ? APPLIANCE_DEFAULTS['os_name'] : ENV['JBOSS_CLOUD_OS_NAME']
      
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_OS_VERSION']}' is not a valid OS version for #{os_name}. Please enter valid version." if !ENV['JBOSS_CLOUD_OS_VERSION'].nil? && !SUPPORTED_OSES[os_name].include?( ENV['JBOSS_CLOUD_OS_VERSION'] )
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_DISK_SIZE']}' is not a valid disk size. Please enter valid size in GB." if !ENV['JBOSS_CLOUD_DISK_SIZE'].nil? && ENV['JBOSS_CLOUD_DISK_SIZE'].to_i == 0
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_MEM_SIZE']}' is not a valid memory size. Please enter valid size in MB." if !ENV['JBOSS_CLOUD_MEM_SIZE'].nil? && ENV['JBOSS_CLOUD_MEM_SIZE'].to_i == 0
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_VCPU']}' is not a valid virtual cpu amount. Please enter valid amount." if !ENV['JBOSS_CLOUD_VCPU'].nil? && ENV['JBOSS_CLOUD_VCPU'].to_i == 0
    end
  end
end
