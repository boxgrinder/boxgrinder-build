module JBossCloud
  class ApplianceConfig
    def initialize
      @appliances = Array.new
    end

    attr_accessor :name
    attr_accessor :arch
    attr_accessor :os_name
    attr_accessor :os_version
    attr_accessor :vcpu
    attr_accessor :mem_size
    attr_accessor :disk_size
    attr_accessor :network_name
    attr_accessor :output_format
    attr_accessor :appliances
    attr_accessor :summary

    # used to checking if configuration diffiers from previous in appliance-kickstart
    def hash
      # without output_format!
      "#{@name}-#{@arch}-#{@os_name}-#{@os_version}-#{@vcpu}-#{@mem_size}-#{@disk_size}-#{@network_name}-#{@appliances.join("-")}-#{@summary}".hash
    end

    def appliance_path
      "#{@arch}/#{@os_name}/#{@os_version}"
    end

    def eql?(other)
      hash == other.hash
    end

  end
  class Config
    SUPPORTED_OSES = { "fedora" => [ "10", "rawhide" ] }
    SUPPORTED_ARCHES = [ "i386", "x86_64" ]

    @@config = nil

    def Config.get
      @@config
    end

    def Config.defaults
      { "os_name" => "fedora", "os_version" => "10", "disk_size" => 2, "mem_size" => 1024, "network_name" => "NAT", "vcpu" => 1, "arch" => (-1.size) == 8 ? "x86_64" : "i386" }
    end

    def Config.supported_arches
      SUPPORTED_ARCHES
    end

    def Config.supported_oses
      SUPPORTED_OSES
    end

    def initialize
    end

    def init( name, version, release, dir_rpms_cache, dir_src_cache, dir_root, dir_top, dir_build, dir_specs, dir_appliances, dir_src, base_pkgs )
      @name             = name
      @version          = version
      @release          = release
      @arch             = (-1.size) == 8 ? "x86_64" : "i386"
      @dir_rpms_cache   = dir_rpms_cache
      @dir_src_cache    = dir_src_cache
      @dir_root         = dir_root
      @dir_top          = dir_top
      @dir_build        = dir_build
      @dir_specs        = dir_specs
      @dir_appliances   = dir_appliances
      @dir_src          = dir_src
      @dir_base         = "#{File.dirname( __FILE__ )}/../.."
      @base_pkgs        = base_pkgs

      # TODO that doesn't look good (code duplication - ApplianceConfigHelper)
      @build_arch       = ENV['JBOSS_CLOUD_ARCH'].nil? ? Config.defaults['arch'] : ENV['JBOSS_CLOUD_ARCH']
      @os_name          = ENV['JBOSS_CLOUD_OS_NAME'].nil? ? Config.defaults['os_name'] : ENV['JBOSS_CLOUD_OS_NAME']
      @os_version       = ENV['JBOSS_CLOUD_OS_VERSION'].nil? ? Config.defaults['os_version'] : ENV['JBOSS_CLOUD_OS_VERSION']

      @@config = self
    end

    attr_reader :name
    attr_reader :version
    attr_reader :release
    attr_reader :build_arch
    attr_reader :arch
    attr_reader :dir_rpms_cache
    attr_reader :dir_src_cache
    attr_reader :dir_root
    attr_reader :dir_top
    attr_reader :dir_build
    attr_reader :dir_specs
    attr_reader :dir_appliances
    attr_reader :dir_src
    attr_reader :dir_base
    attr_reader :base_pkgs
    attr_reader :os_name
    attr_reader :os_version

    attr_accessor :appliance_config

    def build_path
      "#{@arch}/#{@os_name}/#{@os_version}/"
    end

    def version_with_release
      @version + (@release.empty? ? "" : "-" + @release)
    end
  end
end
