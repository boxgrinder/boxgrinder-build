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

require 'rake/tasklib'
require 'yaml'
require 'boxgrinder-build/helpers/guestfs-helper'
require 'boxgrinder-core/helpers/exec-helper'

module BoxGrinder
  class RAWImage < Rake::TaskLib

    def initialize( config, appliance_config, options = {} )
      @config = config
      @appliance_config = appliance_config

      @log          = options[:log]         || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new( { :log => @log } )

      @tmp_dir = "#{@config.dir.root}/#{@config.dir.build}/tmp"

      define_tasks
    end

    def define_tasks
      desc "Build #{@appliance_config.simple_name} appliance."
      task "appliance:#{@appliance_config.name}" => [ @appliance_config.path.file.raw.xml, "appliance:#{@appliance_config.name}:validate:dependencies" ]

      directory @tmp_dir

      file @appliance_config.path.file.raw.xml => [ @appliance_config.path.file.raw.kickstart, "appliance:#{@appliance_config.name}:validate:dependencies", @tmp_dir ] do
        build_raw_image
        do_post_build_operations
      end
    end

    def build_raw_image
      @log.info "Building #{@appliance_config.simple_name} appliance..."

      @exec_helper.execute "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{@tmp_dir} --cache=#{@config.dir.rpms_cache}/#{@appliance_config.main_path} --config #{@appliance_config.path.file.raw.kickstart} -o #{@appliance_config.path.dir.raw.build} --name #{@appliance_config.name} --vmem #{@appliance_config.hardware.memory} --vcpu #{@appliance_config.hardware.cpus}"

      # fix permissions
      @exec_helper.execute "sudo chmod 777 #{@appliance_config.path.dir.raw.build_full}"
      @exec_helper.execute "sudo chmod 666 #{@appliance_config.path.file.raw.disk}"
      @exec_helper.execute "sudo chmod 666 #{@appliance_config.path.file.raw.xml}"

      @log.info "Appliance #{@appliance_config.simple_name} was built successfully."
    end

    def do_post_build_operations
      @log.info "Executing post operations after build..."

      guestfs_helper = GuestFSHelper.new( @appliance_config.path.file.raw.disk, :log => @log )
      guestfs = guestfs_helper.guestfs

      change_configuration( guestfs )
      set_motd( guestfs )
      install_version_files( guestfs )
      install_repos( guestfs )

      @log.debug "Executing post commands from appliance definition file..."
      if @appliance_config.post.base.size > 0
        for cmd in @appliance_config.post.base
          @log.debug "Executing #{cmd}"
          guestfs.sh( cmd )
        end
        @log.debug "Post commands from appliance definition file executed."
      else
        @log.debug "No commands specified, skipping."
      end

      guestfs.close

      @log.info "Post operations executed."
    end

    def change_configuration( guestfs )
      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # don't use DNS for SSH
      guestfs.aug_set( "/files/etc/ssh/sshd_config/UseDNS", "no" )
      guestfs.aug_save
      @log.debug "Augeas changes saved."
    end

    def set_motd( guestfs )
      @log.debug "Setting up '/etc/motd'..."
      # set nice banner for SSH
      motd_file = "/etc/init.d/motd"
      guestfs.upload( "#{@config.dir.base}/src/motd.init", motd_file )
      guestfs.sh( "sed -i s/#VERSION#/'#{@appliance_config.version}.#{@appliance_config.release}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#APPLIANCE#/'#{@appliance_config.name} appliance'/ #{motd_file}" )

      guestfs.sh( "/bin/chmod +x #{motd_file}" )
      guestfs.sh( "/sbin/chkconfig --add motd" )
      @log.debug "'/etc/motd' is nice now."
    end

    def install_version_files( guestfs )
      @log.debug "Installing BoxGrinder version files..."
      guestfs.sh( "echo 'BOXGRINDER_VERSION=#{@config.version_with_release}' > /etc/sysconfig/boxgrinder" )
      guestfs.sh( "echo 'APPLIANCE_NAME=#{@appliance_config.name}' >> /etc/sysconfig/boxgrinder" )
      @log.debug "Version files installed."
    end

    def install_repos( guestfs )
      @log.debug "Installing repositories from appliance definition file..."
      @appliance_config.repos.each do |repo|
        @log.debug "Installing #{repo['name']} repo..."
        repo_file = File.read( "#{@config.dir.base}/src/base.repo").gsub( /#NAME#/, repo['name'] )

        ['baseurl', 'mirrorlist'].each  do |type|
          repo_file << ("#{type}=#{repo[type]}") unless repo[type].nil?
        end

        guestfs.sh("echo '#{repo_file}' > /etc/yum.repos.d/#{repo['name']}.repo")
      end
      @log.debug "Repositories installed."
    end
  end
end
