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

require 'rake/tasklib'

require 'boxgrinder-build/helpers/release-helper'

module BoxGrinder
  class Appliance < Rake::TaskLib

    def initialize(  appliance_definition_file, options = {} )
      @config            = Config.new
      @appliance_definition_file  = appliance_definition_file
      @log               = options[:log] || Logger.new(STDOUT)
      @options           = options[:options]
    end

    def create
      appliance_configs       = ApplianceHelper.new( :log => @log ).read_definitions( @appliance_definition_file )
      appliance_config_helper = ApplianceConfigHelper.new( appliance_configs )

      @appliance_config = appliance_config_helper.merge(clone_object(appliance_configs.values.first).init_arch).initialize_paths

      ApplianceConfigValidator.new( @appliance_config ).validate

      @log.debug "Selected platform: #{@options.platform}."

      if @options.force
        @log.info "Removing previous builds for #{@appliance_config.name} appliance..."
        FileUtils.rm_rf( @appliance_config.path.dir.build )
        @log.debug "Previous builds removed,"
      end

      disk = search_for_built_disks

      if disk.nil?
        os_plugin = OperatingSystemPluginManager.instance.plugins[@appliance_config.os.name.to_sym]
        os_plugin.init( @config, @appliance_config, :log => @log )
        os_plugin.build
      else
        @log.info "Base image for #{@appliance_config.name} appliance already exists, skipping..."
      end

      disk = search_for_built_disks

      PlatformPluginManager.instance.plugins[@options.platform].convert( disk, @config, @appliance_config, :log => @log ) unless @options.platform == :base
    end

    # TODO: better way?
    def clone_object( o )
      Marshal::load(Marshal.dump(o))
    end

    def search_for_built_disks
      disks = Dir[ "#{@appliance_config.path.dir.raw.build_full}/*.raw" ]

      if disks.size == 0
        return nil
      else
        if disks.size == 1
          return disks.first
        else
          raise "More than 1 disk found, aborting."
        end
      end
    end
  end
end
