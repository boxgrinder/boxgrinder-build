
require 'rake'
require 'jboss-cloud/exec'
require 'jboss-cloud/topdir'
require 'jboss-cloud/repodata'
require 'jboss-cloud/rpm'
require 'jboss-cloud/appliance'
require 'jboss-cloud/multi-appliance'
require 'jboss-cloud/config'
require 'ostruct'

module JBossCloud
  class ImageBuilder
    def self.setup(project_config)
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
      valid_archs = [ "i386", "x86_64" ]

      dir_root    = `pwd`.strip
      name        = project_config[:name]
      version     = project_config[:version]
      release     = project_config[:release]
      arch        = (-1.size) == 8 ? "x86_64" : "i386"

      if (!ENV['ARCH'].nil? and !valid_archs.include?( ENV['ARCH']))
        puts "'#{ENV['ARCH']}' is not a valid build architecture. Available architectures: #{valid_archs.join(", ")}, aborting."
        abort
      end

      build_arch = ENV['ARCH'].nil? ? arch : ENV['ARCH']

      if (!ENV['DISK_SIZE'].nil? && (ENV['DISK_SIZE'].to_i == 0 || ENV['DISK_SIZE'].to_i % 1024 > 0))
        puts "'#{ENV['DISK_SIZE']}' is not a valid disk size. Please enter valid size in MB, aborting."
        abort
      end

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

      JBossCloud::Topdir.new( [ 'noarch', 'i386', 'x86_64' ] )

      puts "Building architecture:\t#{Config.get.build_arch}\n\r"

      Dir[ "#{Config.get.dir_specs}/extras/*.spec" ].each do |spec_file|
        JBossCloud::RPM.new( spec_file )
      end

      Dir[ "#{Config.get.dir_appliances}/*/*.appl" ].each do |appliance_def|
        JBossCloud::Appliance.new( build_config( appliance_def ), appliance_def )
      end

      Dir[ "#{Config.get.dir_appliances}/*.mappl" ].each do |multi_appliance_def|
        #JBossCloud::MultiAppliance.new( build_config( File.basename( multi_appliance_def, '.mappl' ) ), multi_appliance_def )
      end
    end

    def build_config(appliance_def)
      config = ApplianceConfig.new

      config.name           = File.basename( appliance_def, '.appl' )
      config.arch           = ENV['ARCH'].nil? ? Config.get.build_arch : ENV['ARCH']
      config.disk_size      = ENV['DISK_SIZE'].nil? ? 2048 : ENV['DISK_SIZE'].to_i
      config.mem_size       = ENV['MEM_SIZE'].nil? ? 1024 : ENV['MEM_SIZE'].to_i
      config.network_name   = ENV['NETWORK_NAME'].nil? ? "NAT" : ENV['NETWORK_NAME']
      config.os_name        = ENV['OS_NAME'].nil? ? "fedora" : ENV['OS_NAME']
      config.os_version     = ENV['OS_VERSION'].nil? ? "10" : ENV['OS_VERSION']
      config.vcpu           = ENV['VCPU'].nil? ? 1 : ENV['VCPU'].to_i
      config.appliances     = get_appliances( config.name )

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
