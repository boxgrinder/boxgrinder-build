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

additional_libs = [ "amazon-ec2", "aws-s3", "net-ssh", "net-sftp" ]

additional_libs.each do |lib|
  $LOAD_PATH.unshift( "#{File.dirname( __FILE__ )}/../#{lib}/lib" )
end

require 'rake'
require 'jboss-cloud/exec'
require 'jboss-cloud/topdir'
require 'jboss-cloud/rpm'
require 'jboss-cloud/rpm-utils'
require 'jboss-cloud/gpg-sign'
require 'jboss-cloud/appliance'
require 'jboss-cloud/config'
require 'jboss-cloud/jboss-cloud-release'
require 'jboss-cloud/validator/validator'
require 'jboss-cloud/validator/appliance-config-parameter-validator'
require 'jboss-cloud/helpers/appliance-config-helper'
require 'jboss-cloud/defaults'
require 'jboss-cloud/helpers/rake-helper'
require 'ostruct'
require 'yaml'

require 'jboss-cloud/helpers/exec-helper'

module JBossCloud
  class ImageBuilder
    def initialize( log, project_config = Hash.new )
      @log = log
      # validates parameters, this is a pre-validation
      ApplianceConfigParameterValidator.new.validate

      name              = project_config[:name]     || DEFAULT_PROJECT_CONFIG[:name]
      version           = project_config[:version]  || DEFAULT_PROJECT_CONFIG[:version]
      release           = project_config[:release]  || DEFAULT_PROJECT_CONFIG[:release]

      # dirs

      dir               = OpenStruct.new
      dir.root          = `pwd`.strip
      dir.build         = project_config[:dir_build]          || DEFAULT_PROJECT_CONFIG[:dir_build]
      dir.top           = project_config[:dir_top]            || "#{dir.build}/topdir"
      dir.src_cache     = project_config[:dir_sources_cache]  || DEFAULT_PROJECT_CONFIG[:dir_sources_cache]
      dir.rpms_cache    = project_config[:dir_rpms_cache]     || DEFAULT_PROJECT_CONFIG[:dir_rpms_cache]
      dir.specs         = project_config[:dir_specs]          || DEFAULT_PROJECT_CONFIG[:dir_specs]
      dir.appliances    = project_config[:dir_appliances]     || DEFAULT_PROJECT_CONFIG[:dir_appliances]
      dir.src           = project_config[:dir_src]            || DEFAULT_PROJECT_CONFIG[:dir_src]
      dir.kickstarts    = project_config[:dir_kickstarts]     || DEFAULT_PROJECT_CONFIG[:dir_kickstarts]

      config_file       = ENV['JBOSS_CLOUD_CONFIG_FILE']      || "#{ENV['HOME']}/.jboss-cloud/config"

      @config = Config.new( name, version, release, dir, config_file )

      define_rules
    end

    def define_rules

      Validator.new( @config, @log )

      Rake::Task[ 'validate:all' ].invoke

      Topdir.new( @config )
      JBossCloudRelease.new( @config )
      RPMUtils.new( @config )
      GPGSign.new( @config, @log )

      directory @config.dir_build
   
      @log.debug "Current architecture: #{@config.arch}"
      @log.debug "Building architecture: #{@config.build_arch}"

      Rake::Task[ "#{@config.dir.top}/#{@config.os_path}/SPECS/jboss-cloud-release.spec" ].invoke

      [ "#{@config.dir.base}/specs/*.spec", "#{@config.dir.specs}/extras/*.spec", "#{@config.dir.top}/#{@config.os_path}/SPECS/*.spec" ].each do |spec_file_dir|
        Dir[ spec_file_dir ].each do |spec_file|
          RPM.new( @config, spec_file, @log )
        end
      end

      Dir[ "#{@config.dir_appliances}/*/*.appl" ].each do |appliance_def|
        Appliance.new( @config, ApplianceConfigHelper.new.config( appliance_def, @config ), appliance_def )
      end
    end
  end
end
