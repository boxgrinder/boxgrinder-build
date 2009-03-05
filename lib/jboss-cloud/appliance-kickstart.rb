require "fileutils"
require 'jboss-cloud/config'
require 'rake/tasklib'
require 'yaml'
require 'erb'

module JBossCloud
  
  class ApplianceKickstart < Rake::TaskLib
    
    def initialize( config )
      @config = config
      define
    end
    
    def configure
      
    end
    
    def define
      
      appliance_build_dir    = "#{Config.get.dir_build}/#{@config.appliance_path}"
      kickstart_file         = "#{appliance_build_dir}/#{@config.name}.ks"
      config_file            = "#{appliance_build_dir}/#{@config.name}.cfg"
      
      definition = { }
      #definition['local_repository_url'] = "file://#{Config.get.dir_top}/RPMS/noarch"
      # 
      # kickstart want to have disk size in MB, we are using GB
      definition['disk_size']            = @config.disk_size * 1024
      definition['appl_name']            = @config.name
      definition['arch']                 = @config.arch
      definition['post_script']          = ''
      definition['exclude_clause']       = ''
      definition['appliance_names']      = @config.appliances
      definition['repos']                = Array.new
      
      def definition.method_missing(sym,*args)
        self[ sym.to_s ]
      end
      
      definition['local_repos'] = [
        "repo --name=jboss-cloud --cost=10 --baseurl=file://#{Config.get.dir_root}/#{Config.get.dir_top}/#{@config.os_path}/RPMS/noarch",
        "repo --name=jboss-cloud-#{@config.arch} --cost=10 --baseurl=file://#{Config.get.dir_root}/#{Config.get.dir_top}/#{@config.os_path}/RPMS/#{@config.arch}",
      ]
      
      definition['local_repos'] << "repo --name=extra-rpms --cost=1 --baseurl=file://#{Dir.pwd}/extra-rpms/noarch" if ( File.exist?( "extra-rpms" ) )
      
      for repo in valid_repos
        #puts repo
        definition['repos'] << "repo --name=#{repo[0]} --cost=40 --#{repo[1]}=#{repo[2]}"   
      end
      
      for appliance_name in @config.appliances
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
      
      file "#{appliance_build_dir}/base-pkgs.ks" do
        base_pkgs = "kickstarts/#{@config.os_name}/#{@config.os_version}/base-pkgs.ks"
        
        unless File.exists?( base_pkgs )
          base_pkgs = "#{File.dirname( __FILE__ )}/../../#{base_pkgs}" 
        end
        
        FileUtils.cp( base_pkgs, "#{appliance_build_dir}/base-pkgs.ks" )
      end
      
      file config_file => [ "appliance:#{@config.name}:config" ] do
        File.open( config_file, "w") {|f| f.write( @config.to_yaml ) }
      end
      
      file "appliance:#{@config.name}:config" do
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
      
      desc "Build kickstart for #{File.basename( @config.name, '-appliance' )} appliance"
      task "appliance:#{@config.name}:kickstart" => [ kickstart_file ]
      
    end
    
    def valid_repos
      os_repos = REPOS[@config.os_name][@config.os_version]
      
      repos = Array.new
      
      for type in [ "base", "updates" ]
        unless os_repos[type].nil?
          
          mirrorlist = os_repos[type]['mirrorlist']
          baseurl = os_repos[type]['baseurl']
          
          name = "#{@config.os_name}-#{@config.os_version}-#{type}"
          
          if mirrorlist.nil?
            repos.push [ name, "baseurl", baseurl ]
          else
            repos.push [ name, "mirrorlist", mirrorlist ]
          end
        end
      end
      
      for repo in repos
        repo[2].gsub!( /#ARCH#/ , @config.arch )
      end
      
      repos
    end
    
    def read_repositories(appliance_definition)
      
      defs = { }
      defs['arch']               = @config.arch
      defs['os_name']            = @config.os_name
      defs['os_version']         = @config.os_version
      defs['os_version_stable']  = STABLE_RELEASES[@config.os_name]
      
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
