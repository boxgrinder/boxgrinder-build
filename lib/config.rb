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

    # used to checking if configuration diffiers from previous in appliance-kickstart
    def hash
      # without output_format!
      "#{@name}-#{@arch}-#{@os_name}-#{@os_version}-#{@vcpu}-#{@mem_size}-#{@disk_size}-#{@network_name}-#{@appliances.join("-")}".hash
    end

    def eql?(other)
      hash == other.hash
    end

  end
  class Config
    @@config = nil

    def Config.get
      @@config
    end

    def initialize
    end

    def init(name, version, release, arch, build_arch, dir_rpms_cache, dir_src_cache, dir_root, dir_top, dir_build )
      @name             = name
      @version          = version
      @release          = release
      @arch             = arch
      @dir_rpms_cache   = dir_rpms_cache
      @dir_src_cache    = dir_src_cache
      @dir_root         = dir_root
      @dir_top          = dir_top
      @dir_build        = dir_build
      @build_arch       = build_arch

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

    def version_with_release
      @version + (@release.empty? ? "" : "-" + @release)
    end
  end
end
