require 'rake/tasklib'
require 'yaml'
require 'erb'

module JBossCloud
  class ApplianceSpec < Rake::TaskLib

    def initialize( config )
      @config = config

      define
    end

    def define

      appliance_build_dir    = "#{Config.get.dir_build}/appliances/#{@config.appliance_path}"

      definition             = YAML.load_file( "#{Config.get.dir_appliances}/#{@config.name}/#{@config.name}.appl" )
      definition['name']     = @config.name
      definition['version']  = Config.get.version
      definition['release']  = Config.get.release
      definition['packages'] = Array.new if definition['packages'] == nil
      definition['packages'] += @config.appliances.select {|v| !v.eql?(@config.name)}

      def definition.method_missing(sym,*args)
        self[ sym.to_s ]
      end

      file "#{appliance_build_dir}/#{@config.name}.spec"=>[ appliance_build_dir ] do
        template = File.dirname( __FILE__ ) + "/appliance.spec.erb"

        erb = ERB.new( File.read( template ) )
        File.open( "#{appliance_build_dir}/#{@config.name}.spec", 'w' ) {|f| f.write( erb.result( definition.send( :binding ) ) ) }
      end

      for p in definition['packages'] 
        if ( JBossCloud::RPM.provides.keys.include?( p ) )

          file "#{Config.get.dir_top}/RPMS/noarch/#{@config.name}-#{Config.get.version_with_release}.noarch.rpm"=>[ "rpm:#{p}" ]
        end
      end
 
      desc "Build RPM spec for #{File.basename( @config.name, "-appliance" )} appliance"
      task "appliance:#{@config.name}:spec" => [ "#{appliance_build_dir}/#{@config.name}.spec" ]
    end

  end

end

