
require 'rake/tasklib'
require 'jboss-cloud/appliance-vmx-image'
require 'yaml'

module JBossCloud
  class ApplianceImage < Rake::TaskLib

    def initialize( config )
      @config = config

      define
    end

    def define

      appliance_build_dir     = "#{Config.get.dir_build}/#{@config.appliance_path}"
      kickstart_file          = "#{appliance_build_dir}/#{@config.name}.ks"
      xml_file                = "#{appliance_build_dir}/#{@config.name}.xml"
      super_simple_name       = File.basename( @config.name, '-appliance' )
      tmp_dir                 = "#{Dir.pwd}/#{Config.get.dir_build}/tmp"

      desc "Build #{super_simple_name} appliance."
      task "appliance:#{@config.name}" => [ xml_file ]

      directory tmp_dir
      
      for appliance_name in @config.appliances
        task "appliance:#{@config.name}:rpms" => [ "rpm:#{appliance_name}" ]  
      end

      file xml_file => [ kickstart_file, "appliance:#{@config.name}:rpms", tmp_dir ] do
        Rake::Task[ 'rpm:repodata:force' ].invoke

        command = "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{tmp_dir} --cache=#{Config.get.dir_rpms_cache}/#{@config.main_path} --config #{kickstart_file} -o #{appliance_build_dir} --name #{@config.name} --vmem #{@config.mem_size} --vcpu #{@config.vcpu}"
        execute_command( command )
      end

      ApplianceVMXImage.new( @config )

    end
  end
end
