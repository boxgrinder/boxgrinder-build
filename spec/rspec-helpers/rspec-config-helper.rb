require 'boxgrinder-core/models/config'
require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/helpers/appliance-config-helper'
require 'boxgrinder-core/helpers/appliance-helper'

Logger.const_set(:TRACE, 0)
Logger.const_set(:DEBUG, 1)
Logger.const_set(:INFO, 2)
Logger.const_set(:WARN, 3)
Logger.const_set(:ERROR, 4)
Logger.const_set(:FATAL, 5)
Logger.const_set(:UNKNOWN, 6)

Logger::SEV_LABEL.insert(0, 'TRACE')

class Logger
  def trace?
    @level <= TRACE
  end

  def trace(progname = nil, &block)
    add(TRACE, nil, progname, &block)
  end
end

module RSpecConfigHelper
  RSPEC_BASE_LOCATION = "#{File.dirname(__FILE__)}/.."

  def generate_config( params = OpenStruct.new )
    config = BoxGrinder::Config.new

    # files
    config.files.base_vmdk  = params.base_vmdk      || "../../../src/base.vmdk"
    config.files.base_vmx   = params.base_vmx       || "../../../src/base.vmx"

    config
  end

  def generate_appliance_config( appliance_definition_file = "#{RSPEC_BASE_LOCATION}/rspec-src/appliances/full.appl" )
    appliance_configs, appliance_config = BoxGrinder::ApplianceHelper.new(:log => Logger.new('/dev/null')).read_definitions( appliance_definition_file )
    appliance_config_helper = BoxGrinder::ApplianceConfigHelper.new( appliance_configs )

    appliance_config_helper.merge(appliance_config.clone.init_arch).initialize_paths
  end

  def generate_appliance_config_gnome( os_version = "11" )
    appliance_config = BoxGrinder::ApplianceConfig.new("valid-appliance-gnome", (-1.size) == 8 ? "x86_64" : "i386", "fedora", os_version)

    appliance_config.disk_size = 2
    appliance_config.summary = "this is a summary"
    appliance_config.network_name = "NAT"
    appliance_config.vcpu = "1"
    appliance_config.mem_size = "1024"
    appliance_config.appliances = [ appliance_config.name ]

    appliance_config
  end
end