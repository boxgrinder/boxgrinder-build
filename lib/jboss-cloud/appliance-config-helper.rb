require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'

module JBossCloud
  class ApplianceConfigHelper

    def config( appliance_def )

      cfg = ApplianceConfig.new

      cfg.name           = File.basename( appliance_def, '.appl' )
      cfg.arch           = ENV['JBOSS_CLOUD_ARCH'].nil? ? DEFAULTS['arch'] : ENV['JBOSS_CLOUD_ARCH']
      cfg.os_name        = ENV['JBOSS_CLOUD_OS_NAME'].nil? ? DEFAULTS['os_name'] : ENV['JBOSS_CLOUD_OS_NAME']
      cfg.os_version     = ENV['JBOSS_CLOUD_OS_VERSION'].nil? ? DEFAULTS['os_version'] : ENV['JBOSS_CLOUD_OS_VERSION']
      cfg.disk_size      = ENV['JBOSS_CLOUD_DISK_SIZE'].nil? ? DEFAULTS['disk_size'] : ENV['JBOSS_CLOUD_DISK_SIZE'].to_i
      cfg.mem_size       = ENV['JBOSS_CLOUD_MEM_SIZE'].nil? ? DEFAULTS['mem_size'] : ENV['JBOSS_CLOUD_MEM_SIZE'].to_i
      cfg.network_name   = ENV['JBOSS_CLOUD_NETWORK_NAME'].nil? ? DEFAULTS['network_name'] : ENV['JBOSS_CLOUD_NETWORK_NAME']
      cfg.vcpu           = ENV['JBOSS_CLOUD_VCPU'].nil? ? DEFAULTS['vcpu'] : ENV['JBOSS_CLOUD_VCPU'].to_i
      cfg.appliances     = get_appliances( cfg.name )

      # TODO make it better!
      yaml_file = YAML.load_file( appliance_def )
      cfg.summary = yaml_file['summary']

      cfg
    end

    protected

    def get_appliances( appliance_name )
      appliances = Array.new

      appliance_def = "#{Config.get.dir_appliances}/#{appliance_name}/#{appliance_name}.appl"

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
