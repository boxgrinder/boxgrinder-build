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

require 'boxgrinder-build/plugins/os/base/rpm-based-os-plugin'
require 'boxgrinder-build/plugins/os/base/kickstart'
require 'boxgrinder-build/plugins/os/base/validators/rpm-dependency-validator'

module BoxGrinder
  class FedoraPlugin < RPMBasedOSPlugin

    FEDORA_REPOS = {
            "12" => {
                    "base" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-12&arch=#ARCH#"
                    },
                    "updates" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f12&arch=#ARCH#"
                    }
            },
            "11" => {
                    "base" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-11&arch=#ARCH#"
                    },
                    "updates" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f11&arch=#ARCH#"
                    }
            },
            "rawhide" => {
                    "base" => {
                            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=#ARCH#"
                    }
            }

    }

    def info
      {
              :name       => :fedora,
              :full_name  => "Fedora",
              :versions   => ["11", "12", "rawhide"]
      }
    end

    def build( config, appliance_config, options = {}  )
      log          = options[:log]         || Logger.new(STDOUT)
      exec_helper  = options[:exec_helper] || ExecHelper.new( { :log => log } )

      disk_path = build_with_appliance_creator( config, appliance_config, FEDORA_REPOS, :log => log, :exec_helper => exec_helper )

      #do_post_build_operations( disk_path )
    end

    def do_post_build_operations( disk_path )
      @log.info "Executing post operations after build..."

      guestfs_helper = GuestFSHelper.new( disk_path, :log => @log )
      guestfs = guestfs_helper.guestfs

      change_configuration( guestfs )
      set_motd( guestfs )
      install_version_files( guestfs )
      install_repos( guestfs )

      @log.debug "Executing post commands from appliance definition file..."
      if @image_config.post.base.size > 0
        for cmd in @image_config.post.base
          @log.debug "Executing #{cmd}"
          guestfs.sh( cmd )
        end
        @log.debug "Post commands from appliance definition file executed."
      else
        @log.debug "No commands specified, skipping."
      end

      guestfs_helper.clean_close
      
      @log.info "Post operations executed."
    end

    def change_configuration( guestfs )
      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # don't use DNS for SSH
      guestfs.aug_set( "/files/etc/ssh/sshd_config/UseDNS", "no" ) if guestfs.exists( '/etc/ssh/sshd_config' ) != 0
      guestfs.aug_save
      @log.debug "Augeas changes saved."
    end

    def set_motd( guestfs )
      @log.debug "Setting up '/etc/motd'..."
      # set nice banner for SSH
      motd_file = "/etc/init.d/motd"
      guestfs.upload( "#{File.dirname( __FILE__ )}/src/motd.init", motd_file )
      guestfs.sh( "sed -i s/#VERSION#/'#{@image_config.version}.#{@image_config.release}'/ #{motd_file}" )
      guestfs.sh( "sed -i s/#APPLIANCE#/'#{@image_config.name} appliance'/ #{motd_file}" )

      guestfs.sh( "/bin/chmod +x #{motd_file}" )
      guestfs.sh( "/sbin/chkconfig --add motd" )
      @log.debug "'/etc/motd' is nice now."
    end

    def install_version_files( guestfs )
      @log.debug "Installing BoxGrinder version files..."
      guestfs.sh( "echo 'BOXGRINDER_VERSION=#{@config.version_with_release}' > /etc/sysconfig/boxgrinder" )
      guestfs.sh( "echo 'APPLIANCE_NAME=#{@image_config.name}' >> /etc/sysconfig/boxgrinder" )
      @log.debug "Version files installed."
    end

    def install_repos( guestfs )
      @log.debug "Installing repositories from appliance definition file..."
      @image_config.repos.each do |repo|
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