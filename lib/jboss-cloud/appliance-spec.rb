require 'rake/tasklib'
require 'yaml'
require 'erb'

module JBossCloud
  class ApplianceSpec < Rake::TaskLib

    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config

      define
    end

    def define

      appliance_build_dir    = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      spec_file              = "#{appliance_build_dir}/#{@appliance_config.name}.spec"

      definition             = YAML.load_file( "#{@config.dir_appliances}/#{@appliance_config.name}/#{@appliance_config.name}.appl" )
      definition['name']     = @appliance_config.name
      definition['version']  = @config.version
      definition['release']  = @config.release
      definition['packages'] = Array.new if definition['packages'] == nil
      definition['packages'] += @appliance_config.appliances.select {|v| !v.eql?(@appliance_config.name)}

      def definition.method_missing(sym,*args)
        self[ sym.to_s ]
      end

      file spec_file => [ appliance_build_dir ] do
        template = File.dirname( __FILE__ ) + "/appliance.spec.erb"

        erb = ERB.new( File.read( template ) )
        File.open( spec_file, 'w' ) {|f| f.write( erb.result( definition.send( :binding ) ) ) }
      end

      for p in definition['packages'] 
        if ( JBossCloud::RPM.provides.keys.include?( p ) )

          file "#{@config.dir_top}/#{@appliance_config.os_path}/RPMS/noarch/#{@appliance_config.name}-#{@config.version_with_release}.noarch.rpm"=>[ "rpm:#{p}" ]
        end
      end
 
      desc "Build RPM spec for #{File.basename( @appliance_config.name, "-appliance" )} appliance"
      task "appliance:#{@appliance_config.name}:spec" => [ spec_file ]
    end

  end

end

