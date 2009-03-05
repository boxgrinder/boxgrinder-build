require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'

module JBossCloud
  class ApplianceConfigHelper
    
    def config( appliance_def, global_config )
      @global_config = global_config
      
      # read from global config, we need it for exporting to yaml file and later to compare latest and new build 
      # don't use 'arch' property from global_config - this is current arch, not what we're going to build for
      arch           = @global_config.build_arch
      os_name        = @global_config.os_name
      os_version     = @global_config.os_version
      
      name           = File.basename( appliance_def, '.appl' )
      
      cfg = ApplianceConfig.new( name, arch, os_name, os_version )
      
      cfg.disk_size      = ENV['JBOSS_CLOUD_DISK_SIZE'].nil? ? APPLIANCE_DEFAULTS['disk_size'] : ENV['JBOSS_CLOUD_DISK_SIZE'].to_i
      cfg.mem_size       = ENV['JBOSS_CLOUD_MEM_SIZE'].nil? ? APPLIANCE_DEFAULTS['mem_size'] : ENV['JBOSS_CLOUD_MEM_SIZE'].to_i
      cfg.network_name   = ENV['JBOSS_CLOUD_NETWORK_NAME'].nil? ? APPLIANCE_DEFAULTS['network_name'] : ENV['JBOSS_CLOUD_NETWORK_NAME']
      cfg.vcpu           = ENV['JBOSS_CLOUD_VCPU'].nil? ? APPLIANCE_DEFAULTS['vcpu'] : ENV['JBOSS_CLOUD_VCPU'].to_i
      cfg.appliances     = get_appliances( cfg.name )
      
      # TODO make it better!
      yaml_file = YAML.load_file( appliance_def )
      cfg.summary = yaml_file['summary']
      
      cfg
    end
    
    protected
    
    def get_appliances( appliance_name )
      appliances = Array.new
      
      appliance_def = "#{@global_config.dir_appliances}/#{appliance_name}/#{appliance_name}.appl"
      
      unless  File.exists?( appliance_def )
        raise ValidationError, "Appliance configuration file for #{appliance_name} doesn't exists, please check your config files"
      end
      
      appliances_read = YAML.load_file( appliance_def )['appliances']
      appliances_read.each { |appl| appliances +=  get_appliances( appl ) } unless appliances_read.nil? or appliances_read.empty?
      appliances.push( appliance_name )
      
      appliances
    end
    
  end
end
