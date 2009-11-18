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

additional_libs = [ "amazon-ec2", "aws-s3", "net-ssh", "net-sftp", "highline", "htauth" ]

additional_libs.each do |lib|
  $LOAD_PATH.unshift( "#{File.dirname( __FILE__ )}/../#{lib}/lib" )
end

require 'rake'
require 'boxgrinder/exec'
require 'boxgrinder/appliance'
require 'boxgrinder/config'
#require 'boxgrinder/boxgrinder-release'
require 'boxgrinder/validator/validator'
require 'boxgrinder/validator/appliance-config-parameter-validator'
require 'boxgrinder/validator/appliance-definition-validator'
require 'boxgrinder/helpers/appliance-config-helper'
require 'boxgrinder/defaults'
require 'boxgrinder/helpers/rake-helper'
require 'boxgrinder/helpers/release-helper'
require 'ostruct'
require 'yaml'

$stderr.reopen("/dev/null")

module BoxGrinder
  class ImageBuilder
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
      dir.src_cache   = project_config[:dir_sources_cache]  || DEFAULT_PROJECT_CONFIG[:dir_sources_cache]
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
      Validator.new( @config )

      Rake::Task[ 'validate:all' ].invoke

      #BoxGrinderRelease.new( @config )
      ReleaseHelper.new( @config )

      directory @config.dir.build

      #@log.debug "Current architecture: #{@config.hardware.arch}"
      #@log.debug "Building architecture: #{@config.build_arch}"

      appliance_definitions = {}

      Dir[ "#{@config.dir.appliances}/*/*.appl", "#{@config.dir.base}/appliances/*.appl" ].each do |appliance_definition_file|
        appliance_definition = YAML.load_file( appliance_definition_file )

        ApplianceDefinitionValidator.new( appliance_definition, appliance_definition_file ).validate

        appliance_definitions[appliance_definition['name']] = { :definition =>  appliance_definition, :file => appliance_definition_file } 
      end

      appliance_config_helper = ApplianceConfigHelper.new( appliance_definitions )

      for appliance_definition in appliance_definitions.values
        Appliance.new( @config, appliance_config_helper.merge( ApplianceConfig.new( appliance_definition ) ) )
      end
    end
  end
end
