#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
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

require 'boxgrinder-core/helpers/log-helper'
require 'yaml'

module BoxGrinder
  class Repo
    def initialize( name, baseurl = nil, mirrorlist = nil )
      @name = name
      @baseurl = baseurl
      @mirrorlist = mirrorlist
    end

    attr_reader :name
    attr_reader :baseurl
    attr_reader :mirrorlist
  end

  class RPMDependencyValidator
    def initialize( config, appliance_config, dir, options = {} )
      @config           = config
      @appliance_config = appliance_config
      @dir              = dir

      @log          = options[:log]         || LogHelper.new
      @exec_helper  = options[:exec_helper] || ExecHelper.new( :log => @log )

      @yum_config_file = "#{@dir.tmp}/yum.conf"

      # Because we're using repoquery command from our building environment, we must ensure, that our repository
      # names are unique
      @magic_hash = "boxgrinder-"
    end

    def resolve_packages
      @log.info "Resolving packages added to #{@appliance_config.name} appliance definition file..."

      package_list = generate_package_list
      generate_yum_config

      invalid = invalid_names( @appliance_config.repos, package_list )

      if invalid.empty?
        @log.info "All additional packages for #{@appliance_config.name} appliance successfully resolved."
      else
        raise "Package#{invalid.size > 1 ? "s" : ""} #{invalid.join(', ')} for #{@appliance_config.name} appliance not found in repositories. Please check package names in appliance definition file."
      end
    end

    def invalid_names( repo_list, package_list )
      @log.debug "Querying package database..."

      unless @appliance_config.is64bit?
        arches = "i386,i486,i586,i686"
      else
        arches = "x86_64"
      end

      root = (@config.dir.root.end_with?('/') ? '' : @config.dir.root)
      repoquery_output = @exec_helper.execute( "repoquery --quiet --disablerepo=* --enablerepo=#{@appliance_config.repos.collect {|r| "#{@magic_hash}#{r['name']}"}.join(",")} -c '#{root}/#{@yum_config_file}' list available #{package_list.join( ' ' )} --nevra --archlist=#{arches},noarch" )

      invalid_names = []

      for name in package_list
        found = false

        repoquery_output.each do |line|
          line = line.strip

          package = line.match( /^([\S]+)-\d+:/ )
          package = package.nil? ? line : package[1]

          if package.size > 0 and name.match( /^#{package.gsub(/[\+]/, '\\+')}/ )
            found = true
          end
        end
        invalid_names += [ name ] unless found
      end

      invalid_names
    end

    def generate_package_list
      packages = []
      for package in @appliance_config.packages
        packages << package unless package.match /^@/ or package.match /^-/
      end
      packages
    end

    def generate_yum_config
      File.open( @yum_config_file, "w") do |f|

        f.puts( "[main]\r\ncachedir=#{Dir.pwd}/#{@dir.tmp}/#{@magic_hash}#{@appliance_config.hardware.arch}-yum-cache/\r\n\r\n" )

        for repo in @appliance_config.repos
          f.puts( "[#{@magic_hash}#{repo['name']}]" )
          f.puts( "name=#{repo['name']}" )
          f.puts( "baseurl=#{repo['baseurl']}" ) unless repo['baseurl'].nil?
          f.puts( "mirrorlist=#{repo['mirrorlist']}" ) unless repo['mirrorlist'].nil?
          f.puts( "enabled=1" )
          f.puts
        end
      end
    end
  end
end
