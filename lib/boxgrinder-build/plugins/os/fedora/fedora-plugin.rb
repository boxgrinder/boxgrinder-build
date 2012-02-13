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

require 'boxgrinder-build/plugins/os/rpm-based/rpm-based-os-plugin'

module BoxGrinder
  class FedoraPlugin < RPMBasedOSPlugin
    SUPPORTED_VERSIONS = ["13", "14", "15", "16", "17", "rawhide"]

    plugin :type => :os, :name => :fedora, :full_name => "Fedora", :versions => SUPPORTED_VERSIONS, :require_root => true

    def after_init
      super
      register_supported_os('fedora', SUPPORTED_VERSIONS)
      set_default_config_value('PAE', true)
    end

    def execute(appliance_definition_file)
      normalize_packages(@appliance_config.packages)

      @repos = {}

      @plugin_info[:versions].each do |version|
        if version.match(/\d+/)
          @repos[version] = {
              "base" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-#{version}&arch=#BASE_ARCH#"},
              "updates" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f#{version}&arch=#BASE_ARCH#"}
          }
        else
          @repos[version] = {"base" => {"mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=#{version}&arch=#BASE_ARCH#"}}
        end
      end

      build_with_appliance_creator(appliance_definition_file, @repos) do |guestfs, guestfs_helper|
        if @appliance_config.os.version >= "15"
          disable_biosdevname(guestfs)
          change_runlevel(guestfs)
          disable_netfs(guestfs)
          link_mtab(guestfs)
        end
      end
    end

    def normalize_packages(packages)
      # https://issues.jboss.org/browse/BGBUILD-89
      packages << '@core'
      packages << "system-config-firewall-base"
      packages << "dhclient"

      packages.delete('kernel')
      packages.delete('kernel-PAE')

      if @appliance_config.is64bit?
        packages << "kernel"
      else
        @plugin_config['PAE'] ? packages << "kernel-PAE" : packages << "kernel"
      end

      if @appliance_config.os.version >= "16"
        packages << "grub2"
      else
        packages << "grub"
      end
    end

    def disable_biosdevname(guestfs)
      @log.debug "Disabling biosdevname..."
      if guestfs.exists("/boot/grub2/grub.cfg") != 0
        guestfs.write("/etc/default/grub", "GRUB_CMDLINE_LINUX=\"quiet rhgb biosdevname=0\"\n")
        guestfs.sh("cd / && grub2-mkconfig -o /boot/grub2/grub.cfg")
      end
      guestfs.sh('sed -i "s/kernel\(.*\)/kernel\1 biosdevname=0/g" /boot/grub/grub.conf') if guestfs.exists("/boot/grub/grub.conf") != 0
      @log.debug "Biosdevname disabled."
    end

    # https://issues.jboss.org/browse/BGBUILD-204
    def change_runlevel(guestfs)
      @log.debug "Changing runlevel to multi-user non-graphical..."
      guestfs.rm("/etc/systemd/system/default.target")
      guestfs.ln_sf("/lib/systemd/system/multi-user.target", "/etc/systemd/system/default.target")
      @log.debug "Runlevel changed."
    end

    # https://issues.jboss.org/browse/BGBUILD-204
    def disable_netfs(guestfs)
      @log.debug "Disabling network filesystem mounting..."
      guestfs.sh("chkconfig netfs off")
      @log.debug "Network filesystem mounting disabled."
    end
    
    # https://issues.jboss.org/browse/BGBUILD-209
    def link_mtab(guestfs)
      @log.debug "Linking /etc/mtab to /proc/self/mounts..."
      guestfs.ln_sf("/proc/self/mounts", "/etc/mtab")
      @log.debug "/etc/mtab linked."
    end
  end
end

