require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'
require 'yaml'

module JBossCloud
  class ApplianceValidator
    def initialize( appliance_def )
      #check if appliance_def is nil
      raise ValidationError, "Appliance definition file must be specified" if appliance_def.nil?

      @appliance_name = File.basename( appliance_def, '.appl' )

      # check if file exists
      raise ValidationError, "Appliance definition file for '#{@appliance_name}' doesn't exists" unless File.exists?( appliance_def )

      @appliance_def = appliance_def
    end

    def validate
      @definition = YAML.load_file( @appliance_def )
      # check for summary
      raise ValidationError, "Appliance definition file for '#{@appliance_name}' should have summary" if @definition['summary'].nil? or @definition['summary'].length == 0
      # check if all dependent appliances exists
      appliances, valid = get_appliances(@appliance_name)
      raise ValidationError, "Could not find all dependent appliances for multiappliance '#{@appliance_name}'" unless valid
      # check appliance count
      raise ValidationError, "Invalid appliance count for appliance '#{@appliance_name}'" unless appliances.size >= 1
    end

    protected

    def get_config
      validate( build_config )
    end

    
    def get_appliances( appliance_name )
      appliances = Array.new
      valid = true

      appliance_def = "#{Config.get.dir_appliances}/#{appliance_name}/#{appliance_name}.appl"

      unless  File.exists?( appliance_def )
        puts "Appliance configuration file for '#{appliance_name}' doesn't exists, please check your config files."
        return false
      end

      appliances_read = YAML.load_file( appliance_def )['appliances']

      appliances_read.each do |appl|
        appls, v = get_appliances( appl )

        appliances += appls if v
        valid = false unless v
      end unless appliances_read.nil? or appliances_read.empty?

      appliances.push( appliance_name )

      [ appliances, valid ]
    end

  end
end
