# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require "fileutils"
require 'jboss-cloud/config'
require 'rake/tasklib'
require 'yaml'
require 'erb'

module JBossCloud
  
  class ApplianceKickstart < Rake::TaskLib
    
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config
      
      define
    end
    
    def build_definition
      definition = { }
      #definition['local_repository_url'] = "file://#{@config.dir_top}/RPMS/noarch"
      # 
      # kickstart want to have disk size in MB, we are using GB
      definition['disk_size']            = @appliance_config.disk_size * 1024
      definition['appl_name']            = @appliance_config.name
      definition['arch']                 = @appliance_config.arch
      definition['post_script']          = ''
      definition['exclude_clause']       = ''
      definition['appliance_names']      = @appliance_config.appliances
      definition['repos']                = Array.new
      
      def definition.method_missing(sym,*args)
        self[ sym.to_s ]
      end
      
      definition['local_repos'] = [
        "repo --name=jboss-cloud --cost=10 --baseurl=file://#{@config.dir_root}/#{@config.dir_top}/#{@appliance_config.os_path}/RPMS/noarch",
        "repo --name=jboss-cloud-#{@appliance_config.arch} --cost=10 --baseurl=file://#{@config.dir_root}/#{@config.dir_top}/#{@appliance_config.os_path}/RPMS/#{@appliance_config.arch}"
      ]
      
      definition['local_repos'] << "repo --name=extra-rpms --cost=1 --baseurl=file://#{Dir.pwd}/extra-rpms/noarch" if ( File.exist?( "extra-rpms" ) )
      
      for repo in valid_repos
        definition['repos'] << "repo --name=#{repo[0]} --cost=40 --#{repo[1]}=#{repo[2]}"   
      end
      
      for appliance_name in @appliance_config.appliances
        if ( File.exist?( "#{@config.dir_appliances}/#{appliance_name}/#{appliance_name}.post" ) )
          definition['post_script'] += "\n## #{appliance_name}.post\n"
          definition['post_script'] += File.read( "#{@config.dir_appliances}/#{appliance_name}/#{appliance_name}.post" )
        end
        
        all_excludes = []
        
        repo_lines, repo_excludes = read_repositories( "#{@config.dir_appliances}/#{appliance_name}/#{appliance_name}.appl" )
        definition['repos'] += repo_lines
        all_excludes += repo_excludes        
      end
      
      definition['exclude_clause'] = "--excludepkgs=#{all_excludes.join(',')}" unless ( all_excludes.nil? or all_excludes.empty? )
      
      definition
    end
    
    def define
      
      appliance_build_dir    = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      kickstart_file         = "#{appliance_build_dir}/#{@appliance_config.name}.ks"
      config_file            = "#{appliance_build_dir}/#{@appliance_config.name}.cfg"
      
      file "#{appliance_build_dir}/base-pkgs.ks" do
        FileUtils.cp( @config.files.base_pkgs, "#{appliance_build_dir}/base-pkgs.ks" )
      end
      
      file config_file => [ "appliance:#{@appliance_config.name}:config" ] do
        File.open( config_file, "w") {|f| f.write( @appliance_config.to_yaml ) }
      end
      
      file "appliance:#{@appliance_config.name}:config" do
        if File.exists?( config_file )
          unless @appliance_config.eql?( YAML.load_file( config_file ) )
            FileUtils.rm_rf appliance_build_dir
          end
        end
        
        FileUtils.mkdir_p appliance_build_dir
      end
      
      file kickstart_file => [ config_file, "#{appliance_build_dir}/base-pkgs.ks" ] do
        template = File.dirname( __FILE__ ) + "/appliance.ks.erb"
        
        kickstart = ERB.new( File.read( template ) ).result( build_definition.send( :binding ) )
        
        kickstart.gsub!( /#JBOSS_XMX#/ , (@appliance_config.mem_size / 4 * 3).to_s )
        kickstart.gsub!( /#JBOSS_XMS#/ , (@appliance_config.mem_size / 4 * 3 / 4).to_s)
        
        File.open( kickstart_file, 'w' ) {|f| f.write( kickstart ) }
      end      
      
      desc "Build kickstart for #{File.basename( @appliance_config.name, '-appliance' )} appliance"
      task "appliance:#{@appliance_config.name}:kickstart" => [ kickstart_file ]
      
    end
    
    def valid_repos
      os_repos = REPOS[@appliance_config.os_name][@appliance_config.os_version]
      
      repos = Array.new
      
      for type in [ "base", "updates" ]
        unless os_repos[type].nil?
          
          mirrorlist = os_repos[type]['mirrorlist']
          baseurl = os_repos[type]['baseurl']
          
          name = "#{@appliance_config.os_name}-#{@appliance_config.os_version}-#{type}"
          
          if mirrorlist.nil?
            repos.push [ name, "baseurl", baseurl ]
          else
            repos.push [ name, "mirrorlist", mirrorlist ]
          end
        end
      end
      
      for repo in repos
        repo[2].gsub!( /#ARCH#/ , @appliance_config.arch )
      end
      
      repos
    end
    
    def read_repositories(appliance_definition)
      
      defs = { }
      defs['arch']               = @appliance_config.arch
      defs['os_name']            = @appliance_config.os_name
      defs['os_version']         = @appliance_config.os_version
      defs['os_version_stable']  = STABLE_RELEASES[@appliance_config.os_name]
      
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
      
      return [ repos, [ excludes ] ]
    end
  end
  
end
