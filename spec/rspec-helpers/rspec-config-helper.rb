require 'boxgrinder-core/models/config'
require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-core/helpers/appliance-config-helper'

module RSpecConfigHelper
  def generate_config( params = OpenStruct.new )

    dir = OpenStruct.new

    dir.src_cache    = params.dir_src_cache  || "sources_cache"
    dir.rpms_cache   = params.dir_rpms_cache || "rpms_cache"
    dir.root         = params.dir_root       || "/tmp/dir_root"
    dir.top          = params.dir_top        || "topdir"
    dir.build        = params.dir_build      || "build"
    dir.specs        = params.dir_specs      || "specs"
    dir.appliances   = params.dir_appliances || "../../../appliances"
    dir.src          = params.dir_src        || "../../../src"
    dir.base         = params.dir_src        || ".."

    config = BoxGrinder::Config.new( params.name || "BoxGrinder", params.version || "1.0.0", params.release, dir, params.config_file.nil? ? "" : "src/#{params.config_file}" )

    # files
    config.files.base_vmdk  = params.base_vmdk      || "../../../src/base.vmdk"
    config.files.base_vmx   = params.base_vmx       || "../../../src/base.vmx"

    config
  end

  def generate_appliance_config( appliance_definition_file = nil )
    definitions = {}

    if appliance_definition_file.nil?
      definitions["valid-appliance"] =
              {

                      'name'    => "valid-appliance",
                      'summary' => "This is a summary"

              }

    else
      definition = YAML.load_file( appliance_definition_file )
      definitions[definition['name']] = definition
    end

    BoxGrinder::ApplianceConfigHelper.new(definitions).merge(BoxGrinder::ApplianceConfig.new( definitions.values.first ).init_arch).initialize_paths
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