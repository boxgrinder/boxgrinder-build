require 'boxgrinder-build/plugins/os/base-operating-system-plugin'

module BoxGrinder
  class FedoraPlugin < BaseOperatingSystemPlugin
    def info
      {
              :name       => :fedora,
              :full_name  => "Fedora",
              :versions   => ["11", "12"]
      }
    end

    def define( config, image_config, options = {}  )
      @config       = config
      @image_config = image_config

      @log          = options[:log]         || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new( { :log => @log } )

      @tmp_dir = "#{@config.dir.root}/#{@config.dir.build}/tmp"

      Kickstart.new( @config, @image_config, :log => @log )

      desc "Build #{@image_config.simple_name} appliance."
      task "appliance:#{@image_config.name}" => [ @image_config.path.file.raw.xml, "appliance:#{@image_config.name}:validate:dependencies" ]

      directory @tmp_dir

      file @image_config.path.file.raw.xml => [ @image_config.path.file.raw.kickstart, "appliance:#{@image_config.name}:validate:dependencies", @tmp_dir ] do
        build_raw_image
        # do_post_build_operations
      end
    end

    def build_raw_image
      @log.info "Building #{@image_config.simple_name} appliance..."

      @exec_helper.execute "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{@tmp_dir} --cache=#{@config.dir.rpms_cache}/#{@image_config.main_path} --config #{@image_config.path.file.raw.kickstart} -o #{@image_config.path.dir.raw.build} --name #{@image_config.name} --vmem #{@image_config.hardware.memory} --vcpu #{@image_config.hardware.cpus}"

      # fix permissions
      @exec_helper.execute "sudo chmod 777 #{@image_config.path.dir.raw.build_full}"
      @exec_helper.execute "sudo chmod 666 #{@image_config.path.file.raw.disk}"
      @exec_helper.execute "sudo chmod 666 #{@image_config.path.file.raw.xml}"

      @log.info "Appliance #{@image_config.simple_name} was built successfully."
    end

    def do_post_build_operations
      @log.info "Executing post operations after build..."

      guestfs_helper = GuestFSHelper.new( @image_config.path.file.raw.disk, :log => @log )
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

      guestfs.close

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