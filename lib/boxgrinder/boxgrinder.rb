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
require 'boxgrinder/appliance'
require 'boxgrinder/models/config'
require 'boxgrinder/models/appliance-config'
require 'boxgrinder/validators/validator'
require 'boxgrinder/validators/appliance-config-parameter-validator'
require 'boxgrinder/validators/appliance-definition-validator'
require 'boxgrinder/helpers/appliance-config-helper'
require 'boxgrinder/defaults'
require 'boxgrinder/helpers/rake-helper'
require 'ostruct'
require 'yaml'

$stderr.reopen("/dev/null")

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

      definitions = {}

      Dir[ "#{@config.dir.appliances}/**/*.appl", "#{@config.dir.base}/appliances/*.appl" ].each do |file|
        definition = YAML.load_file( file )

        ApplianceDefinitionValidator.new( definition, file ).validate

        definitions[definition['name']] = { :definition =>  definition, :file => file }
      end

      for definition in definitions.values
        Appliance.new( @config, ApplianceConfigHelper.new( definitions ).merge( ApplianceConfig.new( definition ) ).initialize_paths, :log => @log )
      end
    end

    attr_reader :config
  end
end
