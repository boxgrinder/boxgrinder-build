
require 'rake'
require 'jboss-cloud/exec'
require 'jboss-cloud/topdir'
require 'jboss-cloud/repodata'
require 'jboss-cloud/rpm'
require 'jboss-cloud/appliance'
require 'jboss-cloud/config'
require 'jboss-cloud/validator/appliance-validator'
require 'jboss-cloud/validator/parameter-validator'
require 'ostruct'

module JBossCloud
  class ImageBuilder
    def self.setup(project_config)
      # validate entered parameters
      ParameterValidator.new.validate
      
      builder = JBossCloud::ImageBuilder.new( project_config )
      JBossCloud::ImageBuilder.builder = builder
      builder.define_rules
      builder
    end

    def self.builder
      @builder
    end

    def self.builder=(builder)
      @builder = builder
    end

    def config
      @config
    end

    DEFAULT_PROJECT_CONFIG = {
      :build_dir         => 'build',
      #:topdir            =>'build/topdir',
      :sources_cache_dir => 'sources-cache',
      :rpms_cache_dir    => 'rpms-cache',
      :dir_specs         => 'specs',
      :dir_appliances    => 'appliances',
      :dir_src           => 'src',
      :base_pkgs         => 'kickstarts/base-pkgs.ks'
    }

    def initialize(project_config)
      dir_root          = `pwd`.strip
      arch              = (-1.size) == 8 ? "x86_64" : "i386"
      build_arch        = ENV['ARCH'].nil? ? arch : ENV['ARCH']
      name              = project_config[:name]
      version           = project_config[:version]
      release           = project_config[:release]
      dir_build         = project_config[:build_dir]         || DEFAULT_PROJECT_CONFIG[:build_dir]
      dir_top           = project_config[:topdir]            || "#{dir_build}/topdir"
      dir_src_cache     = project_config[:sources_cache_dir] || DEFAULT_PROJECT_CONFIG[:sources_cache_dir]
      dir_rpms_cache    = project_config[:rpms_cache_dir]    || DEFAULT_PROJECT_CONFIG[:rpms_cache_dir]
      dir_specs         = project_config[:dir_specs]         || DEFAULT_PROJECT_CONFIG[:dir_specs]
      dir_appliances    = project_config[:dir_appliances]    || DEFAULT_PROJECT_CONFIG[:dir_appliances]
      dir_src           = project_config[:dir_src]           || DEFAULT_PROJECT_CONFIG[:dir_src]
      base_pkgs         = project_config[:base_pkgs]         || DEFAULT_PROJECT_CONFIG[:base_pkgs]

      Config.new.init( name, version, release, arch, build_arch, dir_rpms_cache, dir_src_cache, dir_root, dir_top, dir_build, dir_specs, dir_appliances, dir_src, File.exists?( base_pkgs ) ? base_pkgs : "#{File.dirname( __FILE__ )}/../../kickstarts/base-pkgs.ks" )
    end
    
    def define_rules

      if Config.get.arch == "i386" and Config.get.build_arch == "x86_64"
        puts "Building x86_64 images from i386 system isn't possible, aborting."
        abort
      end

      directory Config.get.dir_build

      puts "\n\rCurrent architecture:\t#{Config.get.arch}"

      JBossCloud::Topdir.new

      puts "Building architecture:\t#{Config.get.build_arch}\n\r"

      Dir[ "#{Config.get.dir_specs}/extras/*.spec" ].each do |spec_file|
        JBossCloud::RPM.new( spec_file )
      end

      Dir[ "#{Config.get.dir_appliances}/*/*.appl" ].each do |appliance_def|
        # if something goes wrong it raises ValidationError
        ApplianceValidator.new( appliance_def ).validate
        
        JBossCloud::Appliance.new( build_config( appliance_def ), appliance_def )
      end
    end

    def build_config(appliance_def)

      os_name = ENV['OS_NAME'].nil? ? "fedora" : ENV['OS_NAME']
      os_version = ENV['OS_VERSION'].nil? ? "10" : ENV['OS_VERSION']

      unless Config.supported_oses.include?( os_name.to_s ) and Config.supported_oses[os_name.to_s].include?( "#{os_version}" )

        supported = ""

        Config.supported_oses.keys.each do |key|
          supported += "#{key} (#{Config.supported_oses[key].join(", ")})"
        end

        puts "Not supported OS name and/or version selected. Supported are: #{supported}, aborting."
        abort
      end

      config = ApplianceConfig.new

      yaml_file = YAML.load_file( appliance_def )

      config.name           = File.basename( appliance_def, '.appl' )
      config.arch           = ENV['ARCH'].nil? ? Config.get.build_arch : ENV['ARCH']
      config.disk_size      = ENV['DISK_SIZE'].nil? ? 2048 : ENV['DISK_SIZE'].to_i
      config.mem_size       = ENV['MEM_SIZE'].nil? ? 1024 : ENV['MEM_SIZE'].to_i
      config.network_name   = ENV['NETWORK_NAME'].nil? ? "NAT" : ENV['NETWORK_NAME']
      config.os_name        = ENV['OS_NAME'].nil? ? "fedora" : ENV['OS_NAME']
      config.os_version     = ENV['OS_VERSION'].nil? ? "10" : ENV['OS_VERSION']
      config.vcpu           = ENV['VCPU'].nil? ? 1 : ENV['VCPU'].to_i
      config.appliances     = get_appliances( config.name )
      config.summary        = yaml_file['summary']
      
      config
    end

    def get_appliances( appliance_name )
      appliances = Array.new

      appliance_def = "#{Config.get.dir_appliances}/#{appliance_name}/#{appliance_name}.appl"

      unless  File.exists?( appliance_def )
        puts "Appliance configuration file for #{appliance_name} doesn't exists, please check your config files, aborting."
        abort
      end

      appliances_read = YAML.load_file( appliance_def )['appliances']
      appliances_read.each { |appl| appliances +=  get_appliances( appl ) } unless appliances_read.nil? or appliances_read.empty?
      appliances.push( appliance_name )

      appliances
    end

  end
end
