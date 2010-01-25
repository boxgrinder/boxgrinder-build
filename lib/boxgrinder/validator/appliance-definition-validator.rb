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

require 'boxgrinder/validator/errors'

module BoxGrinder
  class ApplianceDefinitionValidator
    def initialize( appliance_definition, appliance_definition_file )
      @appliance_definition = appliance_definition
      @appliance_definition_file = appliance_definition_file
    end

    def validate
      check_for_missing_field( 'name' )

      validate_os
      validate_hardware
      validate_repos
    end

    protected

    def check_for_missing_field( name )
      raise ApplianceValidationError, "Missing field: appliance definition file ('#{@appliance_definition_file}) should have field '#{name}'" if @appliance_definition[name].nil?
    end

    def validate_os
      return if @appliance_definition['os'].nil?

      raise ApplianceValidationError, "Unsupported OS: operating system '#{@appliance_definition['os']['name']}' is not supported. Supported OS types: #{SUPPORTED_OSES.keys.join(", ")}. Please correct your definition file '#{@appliance_definition_file}', thanks" if !@appliance_definition['os']['name'].nil? and !SUPPORTED_OSES.keys.include?( @appliance_definition['os']['name'] )

      #unless @appliance_definition['os']['version'].nil?
        #@appliance_definition['os']['version'] = @appliance_definition['os']['version'].to_s
        #raise ApplianceValidationError, "Not valid OS version: operating system version '#{@appliance_definition['os']['version']}' is not supported for OS type '#{@appliance_definition['os']['name']}'. Supported OS versions for this OS type are: #{SUPPORTED_OSES[@appliance_definition['os']['name']].join(", ")}. Please correct your definition file '#{@appliance_definition_file}', thanks" if !SUPPORTED_OSES[@appliance_definition['os']['name'].nil? ? APPLIANCE_DEFAULTS[:os][:name] : @appliance_definition['os']['name']].include?( @appliance_definition['os']['version'] )
      #end
    end

    def validate_hardware
      return if @appliance_definition['hardware'].nil?

      unless @appliance_definition['hardware']['cpus'].nil?
        raise ApplianceValidationError, "Not valid CPU amount: '#{@appliance_definition['hardware']['cpus']}' is not allowed here. Please correct your definition file '#{@appliance_definition_file}', thanks" if @appliance_definition['hardware']['cpus'] =~ /\d/
        raise ApplianceValidationError, "Not valid CPU amount: Too many or too less CPU's: '#{@appliance_definition['hardware']['cpus']}'. Please choose from 1-4. Please correct your definition file '#{@appliance_definition_file}', thanks" unless @appliance_definition['hardware']['cpus'] >= 1 and @appliance_definition['hardware']['cpus'] <= 4
      end

      unless @appliance_definition['hardware']['memory'].nil?
        raise ApplianceValidationError, "Not valid memory amount: '#{@appliance_definition['hardware']['memory']}' is wrong value. Please correct your definition file '#{@appliance_definition_file}', thanks" if @appliance_definition['hardware']['memory'] =~ /\d/
        raise ApplianceValidationError, "Not valid memory amount: '#{@appliance_definition['hardware']['memory']}' is not allowed here. Memory should be a multiplicity of 64. Please correct your definition file '#{@appliance_definition_file}', thanks" if (@appliance_definition['hardware']['memory'].to_i % 64 > 0)
      end

      unless @appliance_definition['hardware']['partitions'].nil?
        raise ApplianceValidationError, "Not valid partitions format: Please correct your definition file '#{@appliance_definition_file}', thanks" unless @appliance_definition['hardware']['partitions'].class.eql?(Array)

        for partition in @appliance_definition['hardware']['partitions']
          raise ApplianceValidationError, "Not valid partition format: '#{partition}' is wrong value. Please correct your definition file '#{@appliance_definition_file}', thanks" unless partition.class.eql?(Hash)
          raise ApplianceValidationError, "Not valid partition format: Keys 'root' and 'size' should be specified for every partition. Please correct your definition file '#{@appliance_definition_file}', thanks" if !partition.keys.include?("root") or !partition.keys.include?("size")
          raise ApplianceValidationError, "Not valid partition size: '#{partition['size']}' is not a valid value. Please correct your definition file '#{@appliance_definition_file}', thanks" if partition['size'] =~ /\d/ or partition['size'].to_i < 1
        end
      end
    end

    def validate_repos
      return if @appliance_definition['repos'].nil?
      raise ApplianceValidationError, "Not valid repos format: Please correct your definition file '#{@appliance_definition_file}', thanks" unless @appliance_definition['repos'].class.eql?(Array)

      for repo in @appliance_definition['repos']
        raise ApplianceValidationError, "Not valid repo format: '#{repo}' is wrong value. Please correct your definition file '#{@appliance_definition_file}', thanks" unless repo.class.eql?(Hash)
        raise ApplianceValidationError, "Not valid repo format: Please specify name for repository. Please correct your definition file '#{@appliance_definition_file}', thanks" unless repo.keys.include?('name')
        raise ApplianceValidationError, "Not valid repo format: There is no 'mirrorlist' or 'baseurl' specified for '#{repo['name']}' repository. Please correct your definition file '#{@appliance_definition_file}', thanks" unless repo.keys.include?('mirrorlist') or repo.keys.include?('baseurl')
      end
    end
  end
end