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
  class ApplianceConfigHelper

    def initialize( appliance_definitions )
      @appliance_definitions = appliance_definitions
    end

    def merge( appliance_config )
      @appliance_config = appliance_config
      @current_appliances = get_appliances( @appliance_config.name ).reverse

      prepare_os
      prepare_appliances
      prepare_version_and_release

      merge_hardware
      merge_repos
      merge_packages
      merge_post_operations

      @appliance_config
    end

    protected

    def merge_hardware
      merge_cpus
      merge_partitions
      merge_memory
    end

    def merge_cpus
      unless @appliance_config.definition['hardware'].nil? or @appliance_config.definition['hardware']['cpus'].nil?
        @appliance_config.hardware.cpus = @appliance_config.definition['hardware']['cpus']
      end

      merge_field('cpus', 'hardware'){ |cpus| @appliance_config.hardware.cpus = cpus if cpus > @appliance_config.hardware.cpus }

      @appliance_config.hardware.cpus = APPLIANCE_DEFAULTS[:hardware][:cpus] if @appliance_config.hardware.cpus == 0
    end

    # This will merge partitions from multiple appliances.
    def merge_partitions
      partitions = {}

      unless @appliance_config.definition['hardware'].nil? or @appliance_config.definition['hardware']['partitions'].nil?
        for partition in @appliance_config.definition['hardware']['partitions']
          partitions[partition['root']] = partition
        end
      end

      partitions['/'] = { 'root' => '/', 'size' => ENV['BG_HARDWARE_DISK_SIZE'].nil? ? APPLIANCE_DEFAULTS[:hardware][:partition] : ENV['BG_HARDWARE_DISK_SIZE'].to_i } unless partitions.keys.include?('/')

      merge_field('partitions', 'hardware') do |parts|
        for partition in parts
          if partitions.keys.include?(partition['root'])
            partitions[partition['root']]['size'] = partition['size'] if partitions[partition['root']]['size'] < partition['size']
          else
            partitions[partition['root']] = partition
          end
        end
      end

      @appliance_config.hardware.partitions = partitions
    end

    def merge_memory
      @appliance_config.hardware.memory = @appliance_config.definition['hardware']['memory'] unless @appliance_config.definition['hardware'].nil? or @appliance_config.definition['hardware']['memory'].nil?

      merge_field('memory', 'hardware') { |memory| @appliance_config.hardware.memory = memory if memory > @appliance_config.hardware.memory }

      @appliance_config.hardware.memory = APPLIANCE_DEFAULTS[:hardware][:memory] if @appliance_config.hardware.memory == 0
    end

    def prepare_os
      merge_field( 'name', 'os' ) { |name| @appliance_config.os.name = name.to_s }
      merge_field( 'version', 'os' ) { |version| @appliance_config.os.version = version.to_s }
      merge_field( 'password', 'os' ) { |password| @appliance_config.os.password = password.to_s }
    end

    def prepare_appliances
      for appliance in @current_appliances
        @appliance_config.appliances << appliance
      end
    end

    def prepare_version_and_release
      unless @appliance_config.definition['version'].nil?
        @appliance_config.version = @appliance_config.definition['version']
      end

      unless @appliance_config.definition['release'].nil?
        @appliance_config.release = @appliance_config.definition['release']
      end
    end

    def merge_repos
      for appliance_name in @current_appliances
        definition = @appliance_definitions[appliance_name][:definition]

        for repo in definition['repos']
          @appliance_config.repos << repo
        end unless definition['repos'].nil?
      end
    end

    def merge_packages
      for appliance_name in @current_appliances
        definition = @appliance_definitions[appliance_name][:definition]

        unless definition['packages'].nil?
          for package in definition['packages']['includes']
            @appliance_config.packages << package
          end unless definition['packages']['includes'].nil?

          for package in definition['packages']['excludes']
            @appliance_config.packages << "-#{package}"
          end unless definition['packages']['excludes'].nil?
        end
      end
    end

    def merge_post_operations
      for appliance_name in @current_appliances
        definition = @appliance_definitions[appliance_name][:definition]

        unless definition['post'].nil?
          for cmd in definition['post']['base']
            @appliance_config.post.base << cmd
          end unless definition['post']['base'].nil?

          for cmd in definition['post']['ec2']
            @appliance_config.post.ec2 << cmd
          end unless definition['post']['ec2'].nil?

          for cmd in definition['post']['vmware']
            @appliance_config.post.vmware << cmd
          end unless definition['post']['vmware'].nil?
        end

      end
    end

    def merge_field( field, section )
      for appliance_name in @current_appliances
        appliance_definition = @appliance_definitions[appliance_name][:definition]
        next if appliance_definition[section].nil? or appliance_definition[section][field].nil?
        val = appliance_definition[section][field]
        yield val
      end unless @appliance_config.definition['appliances'].nil?
    end

    def get_appliances( appliance_name )
      appliances = []

      if @appliance_definitions.has_key?( appliance_name )
        appliance = @appliance_definitions[appliance_name]
        # add current appliance name
        appliances << appliance[:definition]['name']

        appliance[:definition]['appliances'].each do |appl|
          appliances += get_appliances( appl ) unless appliances.include?( appl )
        end unless appliance[:definition]['appliances'].nil? or appliance[:definition]['appliances'].empty?
      else
        raise ApplianceValidationError, "Not valid appliance name: Specified appliance name '#{appliance_name}' could not be found in appliance list. Please correct your definition file '#{@appliance_config.file}', thanks"
      end

      appliances
    end

  end
end
