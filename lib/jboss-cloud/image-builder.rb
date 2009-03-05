
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
    DEFAULT_PROJECT_CONFIG = {
      :dir_build         => 'build',
      #:topdir            => "#{self.} build/topdir",
      :dir_sources_cache => 'sources-cache',
      :dir_rpms_cache    => 'rpms-cache',
      :dir_specs         => 'specs',
      :dir_appliances    => 'appliances',
      :dir_src           => 'src'
    }
    
    def initialize( project_config )
      # validates parameters, throws ValidationError if something is wrong
      ApplianceConfigParameterValidator.new.validate
      
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
      
      Config.new.init( name, version, release, dir_rpms_cache, dir_src_cache, dir_root, dir_top, dir_build, dir_specs, dir_appliances, dir_src )
      
      define_rules
    end
    
    def define_rules
      
      if Config.get.arch == "i386" and Config.get.build_arch == "x86_64"
        puts "Building x86_64 images from i386 system isn't possible, aborting."
        abort
      end
      
      JBossCloud::Topdir.new
      
      directory Config.get.dir_build
      
      puts "\n\rCurrent architecture:\t#{Config.get.arch}"
      puts "Building architecture:\t#{Config.get.build_arch}\n\r"
      
      Dir[ "#{Config.get.dir_specs}/extras/*.spec" ].each do |spec_file|
        JBossCloud::RPM.new( spec_file )
      end
      
      Dir[ "#{Config.get.dir_appliances}/*/*.appl" ].each do |appliance_def|
        # if something goes wrong it raises ValidationError
        ApplianceValidator.new( appliance_def ).validate
        
        JBossCloud::Appliance.new( ApplianceConfigHelper.new.config( appliance_def ), appliance_def )
      end
    end
  end
end
