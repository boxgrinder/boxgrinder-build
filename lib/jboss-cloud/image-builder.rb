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
require 'jboss-cloud/exec'
require 'jboss-cloud/topdir'
require 'jboss-cloud/repodata'
require 'jboss-cloud/rpm'
require 'jboss-cloud/appliance'
require 'jboss-cloud/config'
require 'jboss-cloud/validator/appliance-validator'
require 'jboss-cloud/validator/appliance-config-parameter-validator'
require 'jboss-cloud/appliance-config-helper'
require 'jboss-cloud/defaults'
require 'ostruct'

module JBossCloud
  class ImageBuilder   
    def initialize( project_config )     
      dir_root          = `pwd`.strip
      name              = project_config[:name]
      version           = project_config[:version]
      release           = project_config[:release]
      
      # dirs
      dir_build         = project_config[:dir_build]         || DEFAULT_PROJECT_CONFIG[:dir_build]
      dir_top           = project_config[:dir_top]           || "#{dir_build}/topdir"
      dir_src_cache     = project_config[:dir_sources_cache] || DEFAULT_PROJECT_CONFIG[:dir_sources_cache]
      dir_rpms_cache    = project_config[:dir_rpms_cache]    || DEFAULT_PROJECT_CONFIG[:dir_rpms_cache]
      dir_specs         = project_config[:dir_specs]         || DEFAULT_PROJECT_CONFIG[:dir_specs]
      dir_appliances    = project_config[:dir_appliances]    || DEFAULT_PROJECT_CONFIG[:dir_appliances]
      dir_src           = project_config[:dir_src]           || DEFAULT_PROJECT_CONFIG[:dir_src]
      
      # validates parameters and config files, throws ValidationError if something is wrong
      validate( dir_appliances )
      
      @config = Config.new( name, version, release, dir_rpms_cache, dir_src_cache, dir_root, dir_top, dir_build, dir_specs, dir_appliances, dir_src )
      
      define_rules
    end
    
    def validate( dir_appliances )
      ApplianceConfigParameterValidator.new.validate
      
      Dir[ "#{dir_appliances}/*/*.appl" ].each do |appliance_def|
        ApplianceValidator.new( dir_appliances, appliance_def ).validate
      end
    end
    
    def define_rules
      
      if @config.arch == "i386" and @config.build_arch == "x86_64"
        puts "Building x86_64 images from i386 system isn't possible, aborting."
        abort
      end
      
      JBossCloud::Topdir.new( @config )
      
      directory @config.dir_build
      
      puts "\n\rCurrent architecture:\t#{@config.arch}"
      puts "Building architecture:\t#{@config.build_arch}\n\r"
      
      Dir[ "#{@config.dir_specs}/extras/*.spec" ].each do |spec_file|
        JBossCloud::RPM.new( @config, spec_file )
      end
      
      Dir[ "#{@config.dir_appliances}/*/*.appl" ].each do |appliance_def|        
        JBossCloud::Appliance.new( @config, ApplianceConfigHelper.new.config( appliance_def, @config ), appliance_def )
      end
    end
  end
end
