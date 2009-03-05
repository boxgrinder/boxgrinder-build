
require 'rake/tasklib'
require 'jboss-cloud/appliance-vmx-image'
require 'yaml'

module JBossCloud
  class ApplianceImage < Rake::TaskLib
    
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config
      
      define
    end
    
    def define
      
      appliance_build_dir     = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      kickstart_file          = "#{appliance_build_dir}/#{@appliance_config.name}.ks"
      xml_file                = "#{appliance_build_dir}/#{@appliance_config.name}.xml"
      super_simple_name       = File.basename( @appliance_config.name, '-appliance' )
      tmp_dir                 = "#{@config.dir_root}/#{@config.dir_build}/tmp"
      
      desc "Build #{super_simple_name} appliance."
      task "appliance:#{@appliance_config.name}" => [ xml_file ]
      
      directory tmp_dir
      
      for appliance_name in @appliance_config.appliances
        task "appliance:#{@appliance_config.name}:rpms" => [ "rpm:#{appliance_name}" ]  
      end
      
      file xml_file => [ kickstart_file, "appliance:#{@appliance_config.name}:rpms", tmp_dir ] do
        Rake::Task[ 'rpm:repodata:force' ].invoke
        
        command = "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{tmp_dir} --cache=#{@config.dir_rpms_cache}/#{@appliance_config.main_path} --config #{kickstart_file} -o #{@config.dir_build}/appliances/#{@appliance_config.main_path} --name #{@appliance_config.name} --vmem #{@appliance_config.mem_size} --vcpu #{@appliance_config.vcpu}"
        execute_command( command )
      end
      
      ApplianceVMXImage.new( @appliance_config )
      
    end
  end
end
