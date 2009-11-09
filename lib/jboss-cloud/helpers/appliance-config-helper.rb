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
  class ApplianceConfigHelper

    def initialize( appliance_definitions )
      @appliance_definitions = appliance_definitions
    end

    def merge( appliance_config )
      @appliance_config = appliance_config

      prepare_os
      prepare_appliances
      prepare_version_and_release

      merge_hardware
      merge_repos
      merge_packages

      @appliance_config
    end

    protected

    def merge_hardware
      merge_partitions
      merge_cpus
      merge_memory
    end

    def hardware( field )
      for appliance_name in @appliance_config.definition['appliances']
        appliance_definition = @appliance_definitions[appliance_name][:definition]
        next if appliance_definition['hardware'].nil? or appliance_definition['hardware'][field].nil?
        val = appliance_definition['hardware'][field]
        yield val
      end unless @appliance_config.definition['appliances'].nil?
    end

    def merge_cpus
      unless @appliance_config.definition['hardware'].nil? or @appliance_config.definition['hardware']['cpus'].nil?
        @appliance_config.hardware.cpus = @appliance_config.definition['hardware']['cpus']
      end

      hardware('cpus'){ |cpus| @appliance_config.hardware.cpus = cpus if cpus > @appliance_config.hardware.cpus }

#      for appliance_name in @appliance_config.definition['appliances']
#        # TODO move this to validator
#        #raise "Appliance '#{appliance_name}' not found. Please make sure you specified correct appliance name in config file for appliance '#{@appliance_config.name}'" unless @appliance_definitions.has_key?( appliance_name )
#
#        appliance_definition = @appliance_definitions[appliance_name][:definition]
#        next if appliance_definition['hardware'].nil? or appliance_definition['hardware']['cpus'].nil?
#        cpus = appliance_definition['hardware']['cpus']
#        @appliance_config.hardware.cpus = cpus if cpus > @appliance_config.hardware.cpus
#      end unless @appliance_config.definition['appliances'].nil?
    end

    # This will merge partitions from multiple appliances.
    def merge_partitions
      partitions = {}

      unless @appliance_config.definition['hardware'].nil? or @appliance_config.definition['hardware']['partitions'].nil?
        for partition in @appliance_config.definition['hardware']['partitions']
          partitions[partition['root']] = partition
        end
      end

      partitions['/'] = { 'root' => '/', 'size' => APPLIANCE_DEFAULTS[:hardware][:partition] } unless partitions.keys.include?('/')

      hardware('partitions') do |partition|
        if partitions.keys.include?(partition['root'])
          partitions[partition['root']]['size'] = partition['size'] if partitions[partition['root']]['size'] < partition['size']
        else
          partitions[partition['root']] = partition
        end
      end

#      for appliance_name in @appliance_config.definition['appliances']
#        appliance_definition = @appliance_definitions[appliance_name][:definition]
#
#        for partition in appliance_definition['hardware']['partitions']
#          if partitions.keys.include?(partition['root'])
#            partitions[partition['root']]['size'] = partition['size'] if partitions[partition['root']]['size'] < partition['size']
#          else
#            partitions[partition['root']] = partition
#          end
#        end unless appliance_definition['hardware'].nil? or appliance_definition['hardware']['partitions'].nil?
#      end unless @appliance_config.definition['appliances'].nil?

      @appliance_config.hardware.partitions = partitions
    end

    def merge_memory
      @appliance_config.hardware.memory = @appliance_config.definition['hardware']['memory'] unless @appliance_config.definition['hardware'].nil? or @appliance_config.definition['hardware']['memory'].nil?

      hardware('memory') { |memory| @appliance_config.hardware.memory = memory if memory > @appliance_config.hardware.memory }

#      for appliance_name in @appliance_config.definition['appliances']
#        # TODO move this to validator
#        #raise "Appliance '#{appliance_name}' not found. Please make sure you specified correct appliance name in config file for appliance '#{@appliance_config.name}'" unless @appliance_definitions.has_key?( appliance_name )
#
#        appliance_definition = @appliance_definitions[appliance_name][:definition]
#        next if appliance_definition['hardware'].nil? or appliance_definition['hardware']['memory'].nil?
#        memory = appliance_definition['hardware']['memory']
#        @appliance_config.hardware.memory = memory if memory > @appliance_config.hardware.memory
#      end unless @appliance_config.definition['appliances'].nil?
    end

    def prepare_os
      unless @appliance_config.definition['os'].nil?
        @appliance_config.os.name = @appliance_config.definition['os']['name'] unless @appliance_config.definition['os']['name'].nil?
        @appliance_config.os.version = @appliance_config.definition['os']['version'] unless @appliance_config.definition['os']['version'].nil?
        @appliance_config.os.password = @appliance_config.definition['os']['password'] unless @appliance_config.definition['os']['password'].nil?
      end
    end

    def prepare_appliances
      for appliance in @appliance_config.definition['appliances']
        @appliance_config.appliances << appliance
      end unless @appliance_config.definition['appliances'].nil?
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
      unless @appliance_config.definition['repos'].nil?
        for repo in @appliance_config.definition['repos']
          @appliance_config.repos << repo
        end
      end

      for appliance_name in @appliance_config.appliances
        definition = @appliance_definitions[appliance_name][:definition]

        for repo in definition['repos']
          @appliance_config.repos << repo
        end unless definition['repos'].nil?
      end
    end

    def merge_packages
      unless @appliance_config.definition['packages'].nil?
        for package in @appliance_config.definition['packages']['includes']
          @appliance_config.packages << package
        end unless @appliance_config.definition['packages']['includes'].nil?

        for package in @appliance_config.definition['packages']['excludes']
          @appliance_config.packages << "-#{package}"
        end unless @appliance_config.definition['packages']['excludes'].nil?
      end


      for appliance_name in @appliance_config.appliances
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

    def get_appliances( appliance_name )
      appliances = Array.new

      appliance_def = "#{@global_config.dir_appliances}/#{appliance_name}/#{appliance_name}.appl"

      unless  File.exists?( appliance_def )
        raise ValidationError, "Appliance configuration file for #{appliance_name} doesn't exists, please check your config files"
      end

      appliances_read = YAML.load_file( appliance_def )['appliances']
      appliances_read.each { |appl| appliances += get_appliances( appl ) } unless appliances_read.nil? or appliances_read.empty?
      appliances.push( appliance_name )

      appliances
    end

  end
end
