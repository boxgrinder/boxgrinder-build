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

require 'boxgrinder-build/plugins/os/base-operating-system-plugin'

module BoxGrinder
  class RPMBasedOSPlugin < BaseOperatingSystemPlugin
    def after_init
      @deliverables[:disk] = "#{@appliance_config.path.dir.raw.build_full}/#{@appliance_config.name}-sda.raw"

      @deliverables[:metadata]  = {
              :descriptor   => "#{@appliance_config.path.dir.raw.build_full}/#{@appliance_config.name}.xml"
      }
    end

    def build_with_appliance_creator( repos = {} )
      Kickstart.new( @config, @appliance_config, repos, :log => @log ).create
      RPMDependencyValidator.new( @config, @appliance_config, @options ).resolve_packages

      tmp_dir = "#{@config.dir.root}/#{@config.dir.build}/tmp"
      FileUtils.mkdir_p( tmp_dir )

      @log.info "Building #{@appliance_config.name} appliance..."

      @exec_helper.execute "sudo appliance-creator -d -v -t #{tmp_dir} --cache=#{@config.dir.rpms_cache}/#{@appliance_config.main_path} --config #{@appliance_config.path.file.raw.kickstart} -o #{@appliance_config.path.dir.raw.build} --name #{@appliance_config.name} --vmem #{@appliance_config.hardware.memory} --vcpu #{@appliance_config.hardware.cpus}"

      # fix permissions
      @exec_helper.execute "sudo chmod 777 #{@appliance_config.path.dir.raw.build_full}"
      @exec_helper.execute "sudo chmod 666 #{@deliverables[:disk]}"
      @exec_helper.execute "sudo chmod 666 #{@deliverables[:metadata][:descriptor]}"

      customize( @deliverables[:disk] ) do |guestfs, guestfs_helper|
        @log.info "Executing post operations after build..."

        unless @appliance_config.post.base.nil?
          @appliance_config.post.base.each do |cmd|
            @log.debug "Executing #{cmd}"
            guestfs.sh( cmd )
          end
          @log.debug "Post commands from appliance definition file executed."
        else
          @log.debug "No commands specified, skipping."
        end

        change_configuration( guestfs )
        set_motd( guestfs )
        install_version_files( guestfs )
        install_repos( guestfs )

        yield guestfs, guestfs_helper if block_given?

        @log.info "Post operations executed."
      end

      @log.info "Base image for #{@appliance_config.name} appliance was built successfully."
    end

    def change_configuration( guestfs )
      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # don't use DNS for SSH
      guestfs.aug_set( "/files/etc/ssh/sshd_config/UseDNS", "no" ) if guestfs.exists( '/etc/ssh/sshd_config' ) != 0
      guestfs.aug_save
      @log.debug "Augeas changes saved."
    end

    def install_version_files( guestfs )
      @log.debug "Installing BoxGrinder version files..."
      guestfs.sh( "echo 'BOXGRINDER_VERSION=#{@config.version_with_release}' > /etc/sysconfig/boxgrinder" )
      guestfs.sh( "echo 'APPLIANCE_NAME=#{@appliance_config.name}' >> /etc/sysconfig/boxgrinder" )
      @log.debug "Version files installed."
    end

    def set_motd( guestfs )
      @log.debug "Setting up '/etc/motd'..."
      # set nice banner for SSH
      motd_file = "/etc/init.d/motd"
      guestfs.upload( "#{File.dirname( __FILE__ )}/src/motd.init", motd_file )
      guestfs.sh( "sed -i s/#VERSION#/'#{@appliance_config.version}.#{@appliance_config.release}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#APPLIANCE#/'#{@appliance_config.name} appliance'/ #{motd_file}" )

      guestfs.sh( "/bin/chmod +x #{motd_file}" )
      guestfs.sh( "/sbin/chkconfig --add motd" )
      @log.debug "'/etc/motd' is nice now."
    end

    def install_repos( guestfs )
      @log.debug "Installing repositories from appliance definition file..."
      @appliance_config.repos.each do |repo|
        if repo['ephemeral']
          @log.debug "Repository '#{repo['name']}' is an ephemeral repo. It'll not be installed in the appliance."
          next
        end

        @log.debug "Installing #{repo['name']} repo..."
        repo_file = File.read( "#{File.dirname( __FILE__ )}/src/base.repo").gsub( /#NAME#/, repo['name'] )

        ['baseurl', 'mirrorlist'].each  do |type|
          repo_file << ("#{type}=#{repo[type]}\n") unless repo[type].nil?
        end

        guestfs.write_file( "/etc/yum.repos.d/#{repo['name']}.repo", repo_file, 0 )
      end
      @log.debug "Repositories installed."
    end

  end
end
