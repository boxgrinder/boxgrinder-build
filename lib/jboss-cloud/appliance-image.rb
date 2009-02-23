
require 'rake/tasklib'
require 'jboss-cloud/appliance-vmx-image'
require 'yaml'

module JBossCloud
  class ApplianceImage < Rake::TaskLib

    def initialize( config, appliance_names=[] )
      @config           = config
      @appliance_names  = appliance_names
      @build_dir        = Config.get.dir_build
      @rpms_cache_dir   = Config.get.dir_rpms_cache
      @version          = Config.get.version
      @release          = Config.get.release

      define
    end

    def define

      appliance_build_dir     = "#{@build_dir}/appliances/#{@config.arch}/#{@config.name}"
      kickstart_file          = "#{appliance_build_dir}/#{@config.name}.ks"
      xml_file                = "#{appliance_build_dir}/#{@config.name}.xml"
      super_simple_name       = File.basename( @config.name, '-appliance' )

      desc "Build #{super_simple_name} appliance."
      task "appliance:#{@config.name}"=>[ xml_file ]

      tmp_dir = "#{Dir.pwd}/#{@build_dir}/tmp"
      directory tmp_dir
      
      for appliance_name in @appliance_names
        task "appliance:#{@config.name}:rpms" => [ "rpm:#{appliance_name}" ]  
      end

      file xml_file => [ kickstart_file, "appliance:#{@config.name}:rpms", tmp_dir ] do
        Rake::Task[ 'rpm:repodata:force' ].invoke

        command = "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{tmp_dir} --cache=#{@rpms_cache_dir}/#{@config.arch} --config #{kickstart_file} -o #{@build_dir}/appliances/#{@config.arch} --name #{@config.name} --vmem #{@config.mem_size} --vcpu #{@config.vcpu}"
        execute_command( command )
      end

      ApplianceVMXImage.new( @config )

    end
  end
end
