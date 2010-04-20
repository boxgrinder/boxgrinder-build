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

require 'boxgrinder-core/validators/errors'
require 'boxgrinder-core/defaults'

module BoxGrinder
  class ApplianceConfigValidator
    def initialize( appliance_config )
      @appliance_config = appliance_config
    end

    def validate
      check_for_missing_field( 'name' )
      check_for_missing_field( 'summary' )

      validate_os
      validate_hardware
      validate_repos
    end

    protected

    def check_for_missing_field( name )
      raise ApplianceValidationError, "Missing field: appliance definition file should have field '#{name}'" if eval("@appliance_config.#{name}").nil?
    end

    def validate_os
      raise ApplianceValidationError, "No operating system selected" if @appliance_config.os.name.nil?

      os_plugin = OperatingSystemPluginManager.instance.plugins[@appliance_config.os.name.to_sym]

      raise ApplianceValidationError, "Not supported operating system selected: #{@appliance_config.os.name}. Supported OSes are: #{OperatingSystemPluginManager.instance.plugins.keys.join(", ")}" if os_plugin.nil?
      raise ApplianceValidationError, "Not supported operating system version selected: #{@appliance_config.os.version}. Supported versions are: #{os_plugin.info[:versions].join(", ")}" unless @appliance_config.os.version.nil? or os_plugin.info[:versions].include?( @appliance_config.os.version )
    end

    def validate_hardware
#      return if @appliance_definition['hardware'].nil?
#
#      unless @appliance_definition['hardware']['cpus'].nil?
#        raise ApplianceValidationError, "Not valid CPU amount: '#{@appliance_definition['hardware']['cpus']}' is not allowed here. Please correct your appliance definition file, thanks." if @appliance_definition['hardware']['cpus'] =~ /\d/
#        raise ApplianceValidationError, "Not valid CPU amount: Too many or too less CPU's: '#{@appliance_definition['hardware']['cpus']}'. Please choose from 1-4. Please correct your appliance definition file, thanks." unless @appliance_definition['hardware']['cpus'] >= 1 and @appliance_definition['hardware']['cpus'] <= 4
#      end

      raise ApplianceValidationError, "Not valid memory amount: '#{@appliance_config.hardware.memory}' is wrong value. Please correct your appliance definition file" if @appliance_config.hardware.memory =~ /\d/
      raise ApplianceValidationError, "Not valid memory amount: '#{@appliance_config.hardware.memory}' is not allowed here. Memory should be multiplicity of 64. Please correct your appliance definition file" if (@appliance_config.hardware.memory.to_i % 64 > 0)

#      unless @appliance_definition['hardware']['partitions'].nil?
#        raise ApplianceValidationError, "Not valid partitions format: Please correct your appliance definition file, thanks." unless @appliance_definition['hardware']['partitions'].class.eql?(Array)
#
#        for partition in @appliance_definition['hardware']['partitions']
#          raise ApplianceValidationError, "Not valid partition format: '#{partition}' is wrong value. Please correct your appliance definition file, thanks." unless partition.class.eql?(Hash)
#          raise ApplianceValidationError, "Not valid partition format: Keys 'root' and 'size' should be specified for every partition. Please correct your appliance definition file, thanks." if !partition.keys.include?("root") or !partition.keys.include?("size")
#          raise ApplianceValidationError, "Not valid partition size: '#{partition['size']}' is not a valid value. Please correct your appliance definition file, thanks." if partition['size'] =~ /\d/ or partition['size'].to_i < 1
#        end
#      end
    end

    def validate_repos
      return if @appliance_config.repos.size == 0

      @appliance_config.repos.each do |repo|
        raise ApplianceValidationError, "Not valid repo format: '#{repo}' is wrong value. Please correct your appliance definition file, thanks." unless repo.class.eql?(Hash)
        raise ApplianceValidationError, "Not valid repo format: Please specify name for repository. Please correct your appliance definition file, thanks." unless repo.keys.include?('name')
        raise ApplianceValidationError, "Not valid repo format: There is no 'mirrorlist' or 'baseurl' specified for '#{repo['name']}' repository. Please correct your appliance definition file, thanks." unless repo.keys.include?('mirrorlist') or repo.keys.include?('baseurl')
      end
    end
  end
end