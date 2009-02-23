require 'rake/tasklib'
require 'yaml'
require 'erb'

module JBossCloud

  class ApplianceKickstart < Rake::TaskLib

    def initialize( config, appliance_names=[] )
      @config            = config
      @build_dir         = Config.get.dir_build
      @topdir            = Config.get.dir_top
      @simple_name       = config.name
      @super_simple_name = File.basename( @simple_name, '-appliance' )
      @appliance_names   = appliance_names
      define
    end

    def configure

    end

    def define

      appliance_build_dir    = "#{@build_dir}/appliances/#{@config.arch}/#{@simple_name}"
      kickstart_file         = "#{appliance_build_dir}/#{@simple_name}.ks"
      config_file            = "#{appliance_build_dir}/#{@simple_name}.cfg"

      definition = { }
      #definition['local_repository_url'] = "file://#{@topdir}/RPMS/noarch"
      definition['disk_size']            = @config.disk_size
      definition['appl_name']            = @config.name
      definition['arch']                 = @config.arch
      definition['post_script']          = ''
      definition['exclude_clause']       = ''
      definition['appliance_names']      = @appliance_names.empty? ? @config.name : @appliance_names
      
      def definition.method_missing(sym,*args)
        self[ sym.to_s ]
      end

      definition['repos'] = [
        "repo --name=jboss-cloud --cost=10 --baseurl=file://#{Config.get.dir_root}/#{@topdir}/RPMS/noarch",
        "repo --name=jboss-cloud-#{@config.arch} --cost=10 --baseurl=file://#{Config.get.dir_root}/#{@topdir}/RPMS/#{@config.arch}",
      ]

      definition['repos'] << "repo --name=extra-rpms --cost=1 --baseurl=file://#{Dir.pwd}/extra-rpms/noarch" if ( File.exist?( "extra-rpms" ) )

      for appliance_name in @appliance_names
        if ( File.exist?( "appliances/#{appliance_name}/#{appliance_name}.post" ) )
          definition['post_script'] += "\n## #{appliance_name}.post\n"
          definition['post_script'] += File.read( "appliances/#{appliance_name}/#{appliance_name}.post" )
        end

        all_excludes = []

        if ( File.exist?( "appliances/#{appliance_name}/#{appliance_name}.appl" ) )
          repo_lines, repo_excludes = read_repositories( "appliances/#{appliance_name}/#{appliance_name}.appl" )
          definition['repos'] += repo_lines
          all_excludes += repo_excludes
        end
      end

      definition['exclude_clause'] = "--excludepkgs=#{all_excludes.join(',')}" unless ( all_excludes.nil? or all_excludes.empty? )

      file "#{appliance_build_dir}/base-pkgs.ks" => [ "kickstarts/base-pkgs.ks" ] do
        FileUtils.cp( "kickstarts/base-pkgs.ks", "#{appliance_build_dir}/base-pkgs.ks" )
      end

      file config_file => [ "appliance:#{@simple_name}:config" ] do
        File.open( config_file, "w") {|f| f.write( @config.to_yaml ) }
      end

      file "appliance:#{@simple_name}:config" do
        if File.exists?( config_file )
          unless @config.eql?( YAML.load_file( config_file ) )
            FileUtils.rm_rf appliance_build_dir
          end
        end

        FileUtils.mkdir_p appliance_build_dir
      end

      file kickstart_file => [ config_file, "#{appliance_build_dir}/base-pkgs.ks" ] do
        template = File.dirname( __FILE__ ) + "/appliance.ks.erb"

        File.open( kickstart_file, 'w' ) {|f| f.write( ERB.new( File.read( template ) ).result( definition.send( :binding ) ) ) }
      end      

      desc "Build kickstart for #{@super_simple_name} appliance"
      task "appliance:#{@simple_name}:kickstart" => [ kickstart_file ]

    end

    def read_repositories(appliance_definition)

      defs = { }
      defs['arch']        = @config.arch
      defs['os_name']     = @config.os_name
      defs['os_version']  = @config.os_version

      def defs.method_missing(sym,*args)
        self[ sym.to_s ]
      end

      definition = YAML.load( ERB.new( File.read( appliance_definition ) ).result( defs.send( :binding ) ) )
      repos_def = definition['repos']
      repos = []
      excludes = []
      unless ( repos_def.nil? )
        repos_def.each do |name,config|
          repo_line = "repo --name=#{name} --baseurl=#{config['baseurl']}"
          unless ( config['filters'].nil? )
            excludes = config['filters']
          end
          repos << repo_line
        end
      end
      return [ repos, excludes ]
    end
  end

end

