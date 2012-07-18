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

require 'boxgrinder-core/models/appliance-config'
require 'boxgrinder-build/plugins/base-plugin'
require 'boxgrinder-build/plugins/os/rpm-based/kickstart'
require 'boxgrinder-build/plugins/os/rpm-based/rpm-dependency-validator'
require 'boxgrinder-build/helpers/linux-helper'
require 'boxgrinder-core/errors'

module BoxGrinder
  class RPMBasedOSPlugin < BasePlugin
    def after_init
      set_default_config_value('format', 'raw')

      register_deliverable(
          :disk => "#{@appliance_config.name}-sda.#{@plugin_config['format']}",
          :descriptor => "#{@appliance_config.name}.xml"
      )

      @linux_helper = LinuxHelper.new(:log => @log)
    end

    # Add default repos (if present) to the list of additional repositories specified in appliance definition.
    def add_repos(repos)
      return if repos.empty?

      repos[@appliance_config.os.version].each do |name, repo|
        r = { 'name' => name, 'ephemeral' => true }

        ['baseurl', 'mirrorlist'].each { |type| r[type] = substitute_vars(repo[type]) unless repo[type].nil? }

        @appliance_config.repos << r
      end
    end

    # Substitute variables in selected string.
    def substitute_vars(str)
      return if str.nil?
      @appliance_config.variables.keys.each do |var|
        str = str.gsub("##{var}#", @appliance_config.variables[var])
      end
      str
    end

    def build_with_appliance_creator(appliance_definition_file, repos = {})
      @appliance_definition_file = appliance_definition_file

      add_repos(repos) if @appliance_config.default_repos

      kickstart_file = Kickstart.new(@config, @appliance_config, @dir, :log => @log).create
      RPMDependencyValidator.new(@config, @appliance_config, @dir, :log => @log).resolve_packages

      @log.info "Building #{@appliance_config.name} appliance..."

      execute_appliance_creator(kickstart_file)

      FileUtils.mv(Dir.glob("#{@dir.tmp}/#{@appliance_config.name}/*"), @dir.tmp)
      FileUtils.rm_rf("#{@dir.tmp}/#{@appliance_config.name}/")

      @image_helper.customize([@deliverables.disk]) do |guestfs, guestfs_helper|
        # TODO is this really needed?
        @log.debug "Uploading '/etc/resolv.conf'..."
        guestfs.upload("/etc/resolv.conf", "/etc/resolv.conf")
        @log.debug "'/etc/resolv.conf' uploaded."

        change_configuration(guestfs_helper)
        # TODO check if this is still required
        apply_root_password(guestfs)
        set_label_for_swap_partitions(guestfs, guestfs_helper)
        use_labels_for_partitions(guestfs)
        disable_firewall(guestfs)
        set_motd(guestfs)
        install_repos(guestfs)
        install_files(guestfs)

        guestfs.sh("chkconfig firstboot off") if guestfs.exists('/etc/init.d/firstboot') != 0

        # https://issues.jboss.org/browse/BGBUILD-148
        recreate_rpm_database(guestfs, guestfs_helper) if @config.os.name != @appliance_config.os.name or @config.os.version != @appliance_config.os.version

        execute_post(guestfs_helper)

        yield guestfs, guestfs_helper if block_given?
      end

      @log.info "Base image for #{@appliance_config.name} appliance was built successfully."
    end

    def execute_appliance_creator(kickstart_file)
      begin
        @exec_helper.execute "appliance-creator -d -v -t '#{@dir.tmp}' --cache=#{@config.dir.cache}/rpms-cache/#{@appliance_config.path.main} --config '#{kickstart_file}' -o '#{@dir.tmp}' --name '#{@appliance_config.name}' --vmem #{@appliance_config.hardware.memory} --vcpu #{@appliance_config.hardware.cpus} --format #{@plugin_config['format']}"
      rescue InterruptionError => e
        cleanup_after_appliance_creator(e.pid)
        abort
      end
    end

    def execute_post(guestfs_helper)
      @log.info "Executing post operations after build..."
      unless @appliance_config.post['base'].nil?
        @appliance_config.post['base'].each do |cmd|
          guestfs_helper.sh(cmd, :arch => @appliance_config.hardware.arch)
        end
        @log.debug "Post commands from appliance definition file executed."
      else
        @log.debug "No commands specified, skipping."
      end
    end

    # https://issues.jboss.org/browse/BGBUILD-148
    def recreate_rpm_database(guestfs, guestfs_helper)
      @log.debug "Recreating RPM database..."

      guestfs.download("/var/lib/rpm/Packages", "#{@dir.tmp}/Packages")
      @exec_helper.execute("/usr/lib/rpm/rpmdb_dump #{@dir.tmp}/Packages > #{@dir.tmp}/Packages.dump")
      guestfs.upload("#{@dir.tmp}/Packages.dump", "/tmp/Packages.dump")
      guestfs.sh("rm -rf /var/lib/rpm/*")
      guestfs_helper.sh("cd /var/lib/rpm/ && cat /tmp/Packages.dump | /usr/lib/rpm/rpmdb_load Packages")
      guestfs_helper.sh("rpm --rebuilddb")

      @log.debug "RPM database recreated..."
    end

    def cleanup_after_appliance_creator(pid)
      @log.debug "Sending TERM signal to process '#{pid}'..."
      Process.kill("TERM", pid)

      @log.debug "Waiting for process to be terminated..."
      Process.wait(pid)

      @log.debug "Cleaning appliance-creator mount points..."

      Dir["#{@dir.tmp}/imgcreate-*"].each do |dir|
        dev_mapper = @exec_helper.execute("mount | grep #{dir} | awk '{print $1}'").split("\n")

        mappings = {}

        dev_mapper.each do |mapping|
          if mapping =~ /(loop\d+)p(\d+)/
            mappings[$1] = [] if mappings[$1].nil?
            mappings[$1] << $2 unless mappings[$1].include?($2)
          end
        end

        (['/var/cache/yum', '/dev/shm', '/dev/pts', '/proc', '/sys'] + @appliance_config.hardware.partitions.keys.sort.reverse).each do |mount_point|
          @log.trace "Unmounting '#{mount_point}'..."
          @exec_helper.execute "umount -d #{dir}/install_root#{mount_point}"
        end

        mappings.each do |loop, partitions|
          @log.trace "Removing mappings from loop device #{loop}..."
          @exec_helper.execute "/sbin/kpartx -d /dev/#{loop}"
          @exec_helper.execute "losetup -d /dev/#{loop}"

          partitions.each do |part|
            @log.trace "Removing mapping for partition #{part} from loop device #{loop}..."
            @exec_helper.execute "rm /dev/#{loop}#{part}"
          end
        end
      end

      @log.debug "Cleaned up after appliance-creator."
    end

    # https://issues.jboss.org/browse/BGBUILD-177
    def disable_firewall(guestfs)
      @log.debug "Disabling firewall..."
      guestfs.sh("lokkit -q --disabled")
      @log.debug "Firewall disabled."
    end

    # https://issues.jboss.org/browse/BGBUILD-301
    def set_label_for_swap_partitions(guestfs, guestfs_helper)
      @log.trace "Searching for swap partition to set label..."

      guestfs_helper.mountable_partitions(guestfs.list_devices.first, :list_swap => true).each do |p|
        if guestfs.vfs_type(p).eql?('swap')
          @log.debug "Setting 'swap' label for partiiton '#{p}'."
          guestfs.mkswap_L('swap', p)
          @log.debug "Label set."
          # We assume here that nobody will want to have two swap partitions
          break
        end
      end
    end

    def use_labels_for_partitions(guestfs)
      @log.debug "Using labels for partitions..."
      device = guestfs.list_devices.first

      # /etc/fstab
      if fstab = guestfs.read_file('/etc/fstab').gsub!(%r(^(/dev/\w+da\d*))) { |path| "LABEL=#{guestfs.vfs_label(path.gsub('/dev/sda', device))}" }
        guestfs.write_file('/etc/fstab', fstab, 0)
      end

      # /boot/grub/grub.conf
      if guestfs.exists('/boot/grub/grub.conf') != 0
        if grub = guestfs.read_file('/boot/grub/grub.conf').gsub!(%r((/dev/\w+da\d*))) { |path| "LABEL=#{guestfs.vfs_label(path.gsub('/dev/sda', device))}" }
          guestfs.write_file('/boot/grub/grub.conf', grub, 0)
        end
      end
      @log.debug "Done."
    end

    def apply_root_password(guestfs)
      @log.debug "Applying root password..."
      guestfs.sh("/usr/bin/passwd -d root")
      guestfs.sh("/usr/sbin/usermod -p '#{@appliance_config.os.password.crypt((0...8).map { 65.+(rand(25)).chr }.join)}' root")
      @log.debug "Password applied."
    end

    def change_configuration(guestfs_helper)
      guestfs_helper.augeas do
        set('/etc/ssh/sshd_config', 'UseDNS', 'no')
        set('/etc/sysconfig/selinux', 'SELINUX', 'permissive')
      end
    end

    def set_motd(guestfs)
      @log.debug "Setting up '/etc/motd'..."
      # set nice banner for SSH
      motd_file = "/etc/init.d/motd"
      guestfs.upload("#{File.dirname(__FILE__)}/src/motd.init", motd_file)
      guestfs.sh("sed -i s/#VERSION#/'#{@appliance_config.version}.#{@appliance_config.release}'/ #{motd_file}")
      guestfs.sh("sed -i s/#APPLIANCE#/'#{@appliance_config.name} appliance'/ #{motd_file}")

      guestfs.sh("/bin/chmod +x #{motd_file}")
      guestfs.sh("/sbin/chkconfig --add motd")
      @log.debug "'/etc/motd' is nice now."
    end

    def recreate_kernel_image(guestfs, modules = [])
      @linux_helper.recreate_kernel_image(guestfs, modules)
    end

    def install_repos(guestfs)
      @log.debug "Installing repositories from appliance definition file..."

      # It seems that the directory is not always created by default if default repos are inhibited (e.g. SL6)
      yum_d = '/etc/yum.repos.d/'
      guestfs.mkdir_p(yum_d) if guestfs.exists(yum_d) == 0

      @appliance_config.repos.each do |repo|
        if repo['ephemeral']
          @log.debug "Repository '#{repo['name']}' is an ephemeral repo. It'll not be installed in the appliance."
          next
        end

        @log.debug "Installing #{repo['name']} repo..."
        repo_file = File.read("#{File.dirname(__FILE__)}/src/base.repo").gsub(/#NAME#/, repo['name'])

        ['baseurl', 'mirrorlist'].each do |type|
          repo_file << ("#{type}=#{repo[type]}\n") unless repo[type].nil?
        end

        guestfs.write_file("#{yum_d}#{repo['name']}.repo", repo_file, 0)
      end
      @log.debug "Repositories installed."
    end

    # Copies specified files into appliance.
    #
    # There are two types of paths:
    # 1. remote - starting with http:// or https:// or ftp://
    # 2. local - all other.
    #
    # Please use relative paths. Relative means relative to the appliance definition file.
    # Using absolute paths will cause creating whole directory structure in appliance,
    # which is most probably not exactly what you want.
    #
    # https://issues.jboss.org/browse/BGBUILD-276
    def install_files(guestfs)
      @log.debug "Installing files specified in appliance definition file..."

      @appliance_config.files.each do |dir, files|

        @log.debug "Proceding files for '#{dir}' destination directory..."

        local_files = []

        # Create the directory if it doesn't exists
        guestfs.mkdir_p(dir) unless guestfs.exists(dir) != 0

        files.each do |f|
          if f.match(/^(http|ftp|https):\/\//)
            # Remote url provided
            @log.trace "Remote url detected: '#{f}'."

            # We have a remote file, try to download it using curl!
            guestfs.sh("cd #{dir} && curl -O -L #{f}")
          else
            @log.trace "Local path detected: '#{f}'."

            file_path = (f.match(/^\//) ? f : "#{File.dirname(@appliance_definition_file)}/#{f}")

            # TODO validate this earlier
            raise ValidationError, "File '#{f}' specified in files section of appliance definition file doesn't exists." unless File.exists?(file_path)

            local_files << f
          end
        end

        next if local_files.empty?

        @log.trace "Tarring files..."
        @exec_helper.execute("cd #{File.dirname(@appliance_definition_file)} && tar -cvf /tmp/bg_install_files.tar --wildcards #{local_files.join(' ')}")
        @log.trace "Files tarred."

        @log.trace "Uploading and unpacking..."
        guestfs.tar_in("/tmp/bg_install_files.tar", dir)
        @log.trace "Files uploaded."

      end
      @log.debug "Files installed."
    end
  end
end
