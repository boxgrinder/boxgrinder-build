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

require 'yaml'

module JBossCloud
  class Repo
    def initialize(name, baseurl = nil, mirrorlist = nil)
      @name         = name
      @baseurl      = baseurl
      @mirrorlist   = mirrorlist
    end

    attr_reader :name
    attr_reader :baseurl
    attr_reader :mirrorlist
  end

  class ApplianceDependencyValidator
    def initialize( config, appliance_config )
      @config             = config
      @appliance_config   = appliance_config

      @log          = LOG
      @exec_helper  = EXEC_HELPER

      appliance_build_dir     = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      @kickstart_file         = "#{appliance_build_dir}/#{@appliance_config.name}.ks"
      @yum_config_file        = "#{appliance_build_dir}/#{@appliance_config.name}.yum.conf"

      @appliance_defs = []

      for appliance in @appliance_config.appliances do
        @appliance_defs += [ "#{@config.dir.appliances}/#{appliance}/#{appliance}.appl" ]
      end

      # Because we're using repoquery command from our building environment, we must ensure, that our repository
      # names are unique
      @magic_hash = "#{@config.name.downcase}-"

      define_tasks
    end

    def define_tasks
      desc "Validate packages dependencies for #{@appliance_config.simple_name} appliance"
      task "appliance:#{@appliance_config.name}:validate:dependencies" => [ @kickstart_file ] do
        # if RAW file is already built, don't check for dependencies
        unless File.exists?( @appliance_config.path.file.raw )
          Rake::Task[ "appliance:#{@appliance_config.name}:rpms" ].invoke
          Rake::Task[ 'rpm:repodata:force' ].invoke

          resolve_packages
        end
      end

      task "appliance:all:validate:dependencies" => [ "appliance:#{@appliance_config.name}:validate:dependencies" ]
    end

    def resolve_packages
      @log.info "Resolving packages added to #{@appliance_config.simple_name} appliance definition file..."

      repos         = read_repos_from_kickstart_file
      package_list  = generate_package_list + [ @appliance_config.name ]
      repo_list     = generate_repo_list( repos )

      begin
        generate_yum_config( repos )

        invalid_names = invalid_names( repo_list, package_list )

        if invalid_names.size == 0
          @log.info "All additional packages for #{@appliance_config.simple_name} appliance successfully resolved."
        else
          raise "Package#{invalid_names.size > 1 ? "s" : ""} #{invalid_names.join(', ')} for #{@appliance_config.simple_name} appliance not found in repositories. Please check package name in appliance definition files (#{@appliance_defs.join(', ')})"
        end
      rescue => e
        EXCEPTION_HELPER.log_and_exit( e )
      end
    end

    def invalid_names( repo_list, package_list )
      @log.info "Quering package database..."

      repoquery_output = @exec_helper.execute( "sudo repoquery --disablerepo=* --enablerepo=#{repo_list} -c #{@yum_config_file} list available #{package_list.join( ' ' )} --nevra --archlist=#{@appliance_config.arch},noarch" )
      invalid_names    = []

      for name in package_list
        found = false

        repoquery_output.each do |line|
          name_from_output = line.strip.match( /^([\S]+)-\d+:/ )[1]

          if name.match( /^#{name_from_output.gsub(/[\+]/, '\\+')}/ )
            found = true
          end
        end
        invalid_names += [ name ] unless found
      end

      invalid_names
    end

    def generate_package_list
      packages = []

      for appliance_def in @appliance_defs do
        definition = YAML.load_file( appliance_def )
        packages += definition['packages'] unless definition['packages'].nil?
      end

      packages
    end

    def generate_repo_list(repos)
      repo_list = ""

      repos.each do |repo|
        repo_list += "#{@magic_hash}#{repo.name},"
      end

      repo_list = repo_list[0, repo_list.length - 1]
    end

    def read_repos_from_kickstart_file
      repos       = `grep -e "^repo" #{@kickstart_file}`
      repo_list   = []

      repos.each do |repo_line|
        name        = repo_line.match( /--name=([\w\-]+)/ )[1]
        baseurl     = repo_line.match( /--baseurl=([\w\-\:\/\.&\?=]+)/ )
        mirrorlist  = repo_line.match( /--mirrorlist=([\w\-\:\/\.&\?=]+)/ )

        baseurl     = baseurl[1] unless baseurl.nil?
        mirrorlist  = mirrorlist[1] unless mirrorlist.nil?

        repo_list.push( Repo.new( name, baseurl, mirrorlist ) )
      end

      repo_list
    end

    def generate_yum_config( repo_list )
      File.open( @yum_config_file, "w") do |f|

        f.puts( "[main]\r\ncachedir=/tmp/#{@config.name.downcase}-#{@appliance_config.arch}-yum-cache/\r\n" )

        for repo in repo_list
          f.puts( "[#{@magic_hash}#{repo.name}]" )
          f.puts( "name=#{repo.name}" )
          f.puts( "baseurl=#{repo.baseurl}" ) unless repo.baseurl.nil?
          f.puts( "mirrorlist=#{repo.mirrorlist}" ) unless repo.mirrorlist.nil?
          f.puts( "enabled=1" )
          f.puts
        end
      end
    end
  end
end