require 'boxgrinder-core/models/appliance-config'

module BoxGrinder
  class ImageDefinitionParser
    def initialize( dirs, types )
      @definitions  = {}
      @configs      = {}

      dirs.each do |dir|
        Dir[ "#{dir}/*.appl" ].each do |file|
          parse_yaml( file )
        end

        Dir[ "#{dir}/*.xml" ].each do |file|
          parse_xml( file )
        end
      end

    end

    def parse_yaml( definition_file )
      store_definition( YAML.load_file( definition_file ) )
    end

    def parse_xml( definition_file )
      raise "Not implemented"
    end

    def store_definition( definition )
      config = ApplianceConfig.new( definition ).init_arch

      @definitions[config.name] = definition
      @configs[config.name]     = config
    end

    attr_reader :configs
    attr_reader :definitions
  end
end