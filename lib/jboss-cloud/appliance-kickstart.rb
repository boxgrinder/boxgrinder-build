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
require 'htauth'

module JBossCloud

  class ApplianceKickstart < Rake::TaskLib

    def initialize( config, appliance_config )
      @config = config
      @appliance_config = appliance_config

      define
    end

    def build_definition
      definition = { }
      #definition['local_repository_url'] = "file://#{@config.dir_top}/RPMS/noarch"
      # 
      # kickstart want to have disk size in MB, we are using GB

      definition['partitions'] = []

      @appliance_config.hardware.partitions.each do |root, partition|
        definition['partitions'] << partition
      end

      definition['name'] = @appliance_config.name
      definition['arch'] = @appliance_config.hardware.arch

      definition['post_script'] = ''
      definition['exclude_clause'] = ''
      definition['appliance_names'] = @appliance_config.appliances
      definition['repos'] = Array.new

      appliance_definition = @appliance_config.definition #YAML.load_file( "#{@config.dir_appliances}/#{@appliance_config.name}/#{@appliance_config.name}.appl" )

      if SUPPORTED_DESKTOP_TYPES.include?( appliance_definition['desktop'] )
        definition['graphical'] = true

        # default X package groups
        definition['packages'] = [ "@base-x", "@base", "@core", "@fonts", "@input-methods", "@admin-tools", "@dial-up", "@hardware-support", "@printing" ]

        #selected desktop environment
        definition['packages'] += [ "@#{appliance_definition['desktop']}-desktop" ]
      else
        definition['graphical'] = false
        definition['packages'] = Array.new
      end

      # add additional packages from .appl file
      definition['packages'] += appliance_definition['packages'] if !appliance_definition['packages'].nil?

      # TODO is ext4 working?!
      #if (@appliance_config.os_name.eql?("fedora") and @appliance_config.os_version.eql?( "11" ))
      #  definition['fstype'] = "ext4"
      #else
      #  definition['fstype'] = "ext3"
      #end

      definition['users'] = appliance_definition['users']
      definition['fstype'] = "ext3"
      definition['root_password'] = @appliance_config.os.password

      def definition.method_missing(sym, *args)
        self[ sym.to_s ]
      end

      definition['repos'] << "repo --name=oddthesis --cost=10 --baseurl=http://repo.oddthesis.org/packages/#{@appliance_config.os_path}/RPMS/noarch"
      definition['repos'] << "repo --name=oddthesis-#{@appliance_config.hardware.arch} --cost=10 --baseurl=http://repo.oddthesis.org/packages/#{@appliance_config.os_path}/RPMS/#{@appliance_config.hardware.arch}"

      all_excludes = []

      #for repo in @appliance_config.repos
      #  puts repo
      #end

#      for appliance_name in @appliance_config.appliances
#        #TODO remove this
#        #if ( File.exist?( "#{@config.dir.appliances}/#{appliance_name}/#{appliance_name}.post" ) )
#        #  definition['post_script'] += "\n## #{appliance_name}.post\n"
#        #  definition['post_script'] += File.read( "#{@config.dir.appliances}/#{appliance_name}/#{appliance_name}.post" )
#        #end
#
#        repo_lines, repo_excludes = read_repositories( "#{@config.dir.appliances}/#{appliance_name}/#{appliance_name}.appl" )
#        definition['repos'] += repo_lines
#        all_excludes += repo_excludes unless repo_excludes.empty?
#      end

      cost = 40

      for repo in @appliance_config.repos
        if repo.keys.include?('mirrorlist')
          urltype = 'mirrorlist'
        else
          urltype = 'baseurl'
        end

        repo_def = "repo --name=#{repo['name']} --cost=#{cost} --#{urltype}=#{repo[urltype]}"
        cost += 1

        #repo_def += " --excludepkgs=#{all_excludes.join(',')}" unless all_excludes.empty?

        definition['repos'] << repo_def
      end

      for repo in valid_repos
        repo_def = "repo --name=#{repo[0]} --cost=40 --#{repo[1]}=#{repo[2]}"
        repo_def += " --excludepkgs=#{all_excludes.join(',')}" unless all_excludes.empty?

        definition['repos'] << repo_def
      end

      definition['packages'] += @appliance_config.packages

      #puts "Aaaaaaaaaaaaaaaa"
      #puts valid_repos

      #rpmfusion_os_name = @appliance_config.os_name.eql?("rhel") ? "el" : @appliance_config.os_name

      #definition['repos'] << "repo --name=rpmfusion-free-release-#{@appliance_config.arch} --cost=60 --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=free-#{rpmfusion_os_name}-#{@appliance_config.os_version}&arch=#{@appliance_config.arch}"
      #definition['repos'] << "repo --name=rpmfusion-free-updates-#{@appliance_config.arch} --cost=60 --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=free-#{rpmfusion_os_name}-updates-released-#{@appliance_config.os_version}&arch=#{@appliance_config.arch}"

      definition
    end

    def define

      appliance_build_dir = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      kickstart_file = "#{appliance_build_dir}/#{@appliance_config.name}.ks"
      config_file = "#{appliance_build_dir}/#{@appliance_config.name}.cfg"

      #file "#{appliance_build_dir}/base-pkgs.ks" do
      #  FileUtils.cp( @config.files.base_pkgs, "#{appliance_build_dir}/base-pkgs.ks" )
      #end

      file config_file do
        FileUtils.mkdir_p appliance_build_dir
        File.open( config_file, "w") {|f| f.write( @appliance_config.to_yaml ) } unless File.exists?( config_file )
      end

      file "appliance:#{@appliance_config.name}:config" do
        if File.exists?( config_file )
          unless @appliance_config.eql?( YAML.load_file( config_file ) )
            FileUtils.rm_rf appliance_build_dir
          end
        end
      end

      file kickstart_file => [ config_file ] do
        template = File.dirname( __FILE__ ) + "/appliance.ks.erb"

        kickstart = ERB.new( File.read( template ) ).result( build_definition.send( :binding ) )

        # TODO: remove this!
        #kickstart.gsub!( /#JBOSS_XMX#/, (@appliance_config.hardware.memory / 4 * 3).to_s )
        #kickstart.gsub!( /#JBOSS_XMS#/, (@appliance_config.hardware.memory / 4 * 3 / 4).to_s)

        File.open( kickstart_file, 'w' ) {|f| f.write( kickstart ) }
      end

      #desc "Build kickstart for #{File.basename( @appliance_config.name, '-appliance' )} appliance"
      task "appliance:#{@appliance_config.name}:kickstart" => [ "appliance:#{@appliance_config.name}:config", kickstart_file ]

    end

    def valid_repos
      os_repos = REPOS[@appliance_config.os.name][@appliance_config.os.version]

      repos = Array.new

      for type in [ "base", "updates" ]
        unless os_repos[type].nil?

          mirrorlist = os_repos[type]['mirrorlist']
          baseurl = os_repos[type]['baseurl']

          name = "#{@appliance_config.os.name}-#{@appliance_config.os.version}-#{type}"

          if mirrorlist.nil?
            repos.push [ name, "baseurl", baseurl ]
          else
            repos.push [ name, "mirrorlist", mirrorlist ]
          end
        end
      end

      for repo in repos
        repo[2].gsub!( /#ARCH#/, @appliance_config.hardware.arch )
      end

      repos
    end

    def read_repositories( repos )

      defs = { }
      defs['arch'] = @appliance_config.hardware.arch
      defs['os_name'] = @appliance_config.os.name
      defs['os_version'] = @appliance_config.os.version
      defs['os_version_stable'] = LATEST_STABLE_RELEASES[@appliance_config.os.name]

      def defs.method_missing(sym, *args)
        self[ sym.to_s ]
      end

      definition = YAML.load( ERB.new( File.read( appliance_definition ) ).result( defs.send( :binding ) ) )
      repos_def = definition['repos']
      repos = []
      excludes = []
      unless ( repos_def.nil? )
        repos_def.each do |name, config|
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
