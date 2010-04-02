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

require 'rake'
require 'boxgrinder-core/defaults'
require 'boxgrinder-core/models/config'
require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/helpers/appliance-config-helper'
require 'boxgrinder-build/defaults'
require 'boxgrinder-build/appliance'
require 'boxgrinder-build/managers/operating-system-plugin-manager'
require 'boxgrinder-build/managers/platform-plugin-manager'
require 'boxgrinder-build/validators/validator'
require 'boxgrinder-build/validators/appliance-config-parameter-validator'
#require 'boxgrinder-build/validators/appliance-definition-validator'
require 'boxgrinder-build/helpers/rake-helper'
require 'ostruct'
require 'yaml'

Dir["#{File.dirname( __FILE__ )}/../plugins/**/*-plugin.rb"].each {|file| require file }

#$stderr.reopen('/dev/null')

module BoxGrinder
  class BoxGrinder
    def initialize( project_config = Hash.new )
      @log = LOG
      # validates parameters, this is a pre-validation
      ApplianceConfigParameterValidator.new.validate

      name    =   project_config[:name]     || DEFAULT_PROJECT_CONFIG[:name]
      version =   project_config[:version]  || DEFAULT_PROJECT_CONFIG[:version]
      release =   project_config[:release]  || DEFAULT_PROJECT_CONFIG[:release]

      # dirs

      dir = OpenStruct.new
      dir.root        = `pwd`.strip
      dir.base        = "#{File.dirname( __FILE__ )}/../../"
      dir.build       = project_config[:dir_build]          || DEFAULT_PROJECT_CONFIG[:dir_build]
      dir.top         = project_config[:dir_top]            || "#{dir.build}/topdir"
      dir.src_cache   = project_config[:dir_src_cache]      || DEFAULT_PROJECT_CONFIG[:dir_src_cache]
      dir.rpms_cache  = project_config[:dir_rpms_cache]     || DEFAULT_PROJECT_CONFIG[:dir_rpms_cache]
      dir.specs       = project_config[:dir_specs]          || DEFAULT_PROJECT_CONFIG[:dir_specs]
      dir.appliances  = project_config[:dir_appliances]     || DEFAULT_PROJECT_CONFIG[:dir_appliances]
      dir.src         = project_config[:dir_src]            || DEFAULT_PROJECT_CONFIG[:dir_src]
      dir.kickstarts  = project_config[:dir_kickstarts]     || DEFAULT_PROJECT_CONFIG[:dir_kickstarts]

      config_file = ENV['BG_CONFIG_FILE'] || "#{ENV['HOME']}/.boxgrinder/config"

      @config = Config.new( name, version, release, dir, config_file )

      define_rules
    end

    def define_rules
      Validator.new( @config, :log => @log )

      Rake::Task[ 'validate:all' ].invoke

      directory @config.dir.build

      # load all plugins (os an platform)
      Dir["#{File.dirname( __FILE__ )}/plugins/**/*.rb"].each {|file| require file }

      load_os_plugins
      load_platform_plugins

      definitions = {}

      Dir[ "#{@config.dir.appliances}/**/*.appl", "#{@config.dir.base}/appliances/*.appl" ].each do |file|
        definition = YAML.load_file( file )

        #TODO validate this AFTER it's converted to a object
        #ApplianceDefinitionValidator.new( definition ).validate

        definitions[definition['name']] = definition
      end

      for definition in definitions.values
        Appliance.new( @config, ApplianceConfigHelper.new( definitions ).merge( ApplianceConfig.new( definition ).init_arch ).initialize_paths, :log => @log )
      end
    end

    def load_os_plugins
      @log.debug "Loading operating system plugins..."

      plugins = OperatingSystemPluginManager.instance.initialize_plugins.plugins

      @log.debug "We have #{plugins.size} operating system plugin(s) registered"

      plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]} #{plugin.info[:versions].join(', ')}."
      end

      @log.debug "Plugins loaded."
    end

    def load_platform_plugins
      @log.debug "Loading platform plugins..."

      plugins = PlatformPluginManager.instance.initialize_plugins.plugins

      @log.debug "We have #{plugins.size} platform plugin(s) registered"

      plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]}."
      end
      
      @log.debug "Plugins loaded."
    end

    attr_reader :config
  end
end
