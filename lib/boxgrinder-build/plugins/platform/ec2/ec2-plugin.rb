require 'boxgrinder-build/plugins/platform/base-platform-plugin'
require 'boxgrinder-build/helpers/aws-helper'
require 'AWS'
require 'aws/s3'
include AWS::S3

module BoxGrinder
  class EC2Plugin < BasePlatformPlugin
    def info
      {
              :name       => :ec2,
              :full_name  => "Amazon Elastic Compute Cloud"
      }
    end

    def define( config, image_config, options = {}  )
      @config       = config
      @image_config = image_config

      @log          = options[:log]         || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new( :log => @log )

      directory @image_config.path.dir.ec2.bundle

      # TODO we should depend on actual disk file, not xml I think
      file @image_config.path.file.ec2.disk  => [ @image_config.path.file.raw.xml, @image_config.path.dir.ec2.build ] do
        convert_image_to_ec2_format
      end

      file @image_config.path.file.ec2.manifest => [ @image_config.path.file.ec2.disk, @image_config.path.dir.ec2.bundle ] do
        @aws_helper = AWSHelper.new( @config, @image_config )
        bundle_image
      end

      task "appliance:#{@image_config.name}:ec2:bundle" => [ @image_config.path.file.ec2.manifest ]

      task "appliance:#{@image_config.name}:ec2:upload" => [ "appliance:#{@image_config.name}:ec2:bundle" ] do
        @aws_helper = AWSHelper.new( @config, @image_config )
        upload_image
      end

      task "appliance:#{@image_config.name}:ec2:register" => [ "appliance:#{@image_config.name}:ec2:upload" ] do
        @aws_helper = AWSHelper.new( @config, @image_config )
        register_image
      end

      desc "Build #{@image_config.simple_name} appliance for Amazon EC2"
      task "appliance:#{@image_config.name}:ec2" => [ @image_config.path.file.ec2.disk ]
    end

    def bundle_image
      @log.info "Bundling AMI..."

      @exec_helper.execute( "ec2-bundle-image -i #{@image_config.path.file.ec2.disk} --kernel #{AWS_DEFAULTS[:kernel_id][@image_config.hardware.arch]} --ramdisk #{AWS_DEFAULTS[:ramdisk_id][@image_config.hardware.arch]} -c #{@aws_helper.aws_data['cert_file']} -k #{@aws_helper.aws_data['key_file']} -u #{@aws_helper.aws_data['account_number']} -r #{@image_config.hardware.arch} -d #{@image_config.path.dir.ec2.bundle}" )

      @log.info "Bundling AMI finished."
    end

    def appliance_already_uploaded?
      begin
        bucket = Bucket.find( @aws_helper.aws_data['bucket_name'] )
      rescue
        return false
      end

      manifest_location = @aws_helper.bucket_manifest_key( @image_config.name )
      manifest_location = manifest_location[ manifest_location.index( "/" ) + 1, manifest_location.length ]

      for object in bucket.objects do
        return true if object.key.eql?( manifest_location )
      end

      false
    end

    def upload_image
      if appliance_already_uploaded?
        @log.debug "Image for #{@image_config.simple_name} appliance is already uploaded, skipping..."
        return
      end

      @log.info "Uploading #{@image_config.simple_name} AMI to bucket '#{@aws_helper.aws_data['bucket_name']}'..."

      @exec_helper.execute( "ec2-upload-bundle -b #{@aws_helper.bucket_key( @image_config.name )} -m #{@image_config.path.file.ec2.manifest} -a #{@aws_helper.aws_data['access_key']} -s #{@aws_helper.aws_data['secret_access_key']} --retry" )
    end

    def register_image
      ami_info    = @aws_helper.ami_info( @image_config.name )

      if ami_info
        @log.info "Image is registered under id: #{ami_info.imageId}"
        return
      else
        ami_info = @aws_helper.ec2.register_image( :image_location => @aws_helper.bucket_manifest_key( @image_config.name ) )
        @log.info "Image successfully registered under id: #{ami_info.imageId}."
      end
    end

    def convert_image_to_ec2_format
      FileUtils.mkdir_p @image_config.path.dir.ec2.build

      @log.info "Converting #{@image_config.simple_name} appliance image to EC2 format..."

      ec2_disk_mount_dir = "#{@config.dir.build}/#{@image_config.appliance_path}/tmp/ec2-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"
      raw_disk_mount_dir = "#{@config.dir.build}/#{@image_config.appliance_path}/tmp/raw-#{rand(9999999999).to_s.center(10, rand(9).to_s)}"

      ec2_prepare_disk
      ec2_create_filesystem

      raw_disk_offset = calculate_disk_offset( @image_config.path.file.raw.disk )

      ec2_loop_device = mount_image(@image_config.path.file.ec2.disk, ec2_disk_mount_dir )
      raw_loop_device = mount_image(@image_config.path.file.raw.disk, raw_disk_mount_dir, raw_disk_offset )

      sync_files( raw_disk_mount_dir, ec2_disk_mount_dir )

      umount_image( @image_config.path.file.raw.disk, raw_disk_mount_dir, raw_loop_device )
      umount_image( @image_config.path.file.ec2.disk, ec2_disk_mount_dir, ec2_loop_device )

      guestfs_helper = GuestFSHelper.new( @image_config.path.file.ec2.disk, :log => @log )
      guestfs = guestfs_helper.guestfs

      create_devices( guestfs )
      upload_fstab( guestfs )

      guestfs.mkdir( "/data" ) if @image_config.is64bit?

      enable_networking( guestfs )
      upload_rc_local( guestfs )

      guestfs_helper.rebuild_rpm_database

      install_additional_packages( guestfs )
      change_configuration( guestfs )

      if @image_config.os.name.eql?("fedora") and @image_config.os.version.to_s.eql?("12")
        @log.debug "Downgrading udev package to use in EC2 environment..."

        repo_included = false

        @image_config.repos.each do |repo|
          repo_included = true if repo['baseurl'] == "http://repo.boxgrinder.org/boxgrinder/packages/fedora/12/RPMS/#{@image_config.hardware.arch}"
        end

        guestfs.upload( "#{File.dirname( __FILE__ )}/src/ec2/f12-#{@image_config.hardware.arch}-boxgrinder.repo", "/etc/yum.repos.d/f12-#{@image_config.hardware.arch}-boxgrinder.repo" ) unless repo_included
        guestfs.sh( "yum -y downgrade udev-142" )
        guestfs.upload( "#{File.dirname( __FILE__ )}/src/f12/yum.conf", "/etc/yum.conf" )
        guestfs.rm_rf( "/etc/yum.repos.d/f12-#{@image_config.hardware.arch}-boxgrinder.repo" ) unless repo_included

        @log.debug "Package udev downgraded."

        # TODO EC2 fix, remove that after Fedora pushes kernels to Amazon
        @log.debug "Disabling unnecessary services..."
        guestfs.sh( "/sbin/chkconfig ksm off" ) if guestfs.exists( "/etc/init.d/ksm" ) != 0
        guestfs.sh( "/sbin/chkconfig ksmtuned off" ) if guestfs.exists( "/etc/init.d/ksmtuned" ) != 0
        @log.debug "Services disabled."
      end

      guestfs.close

      @log.info "Image converted to EC2 format."
    end

    def ec2_prepare_disk
      # TODO add progress bar?
      @log.debug "Preparing disk for EC2 image..."
      @exec_helper.execute "dd if=/dev/zero of=#{@image_config.path.file.ec2.disk} bs=1 count=0 seek=#{10 * 1024}M"
      @log.debug "Disk for EC2 image prepared"
    end

    def ec2_create_filesystem
      @log.debug "Creating filesystem..."
      @exec_helper.execute "mkfs.ext3 -F #{@image_config.path.file.ec2.disk}"
      @log.debug "Filesystem created"
    end

    def calculate_disk_offset( disk )
      loop_device = get_loop_device

      @exec_helper.execute( "sudo losetup #{loop_device} #{disk}" )
      offset = @exec_helper.execute("sudo parted -m #{loop_device} 'unit B print' | grep '^1' | awk -F: '{ print $2 }'").strip.chop
      @exec_helper.execute( "sudo losetup -d #{loop_device}" )

      offset
    end

    def mount_image( disk, mount_dir, offset = 0 )
      loop_device = get_loop_device

      @log.debug "Mounting image #{File.basename( disk )} in #{mount_dir} using #{loop_device} with offset #{offset}"
      FileUtils.mkdir_p( mount_dir )
      @exec_helper.execute( "sudo losetup -o #{offset.to_s} #{loop_device} #{disk}" )
      @exec_helper.execute( "sudo mount #{loop_device} -t ext3 #{ mount_dir}")

      loop_device
    end

    def umount_image( disk, mount_dir, loop_device )
      @log.debug "Unmounting image #{File.basename( disk )}"
      @exec_helper.execute( "sudo umount -d #{loop_device}" )
      FileUtils.rm_rf( mount_dir )
    end


    def sync_files( from_dir, to_dir )
      @log.debug "Syncing files between #{from_dir} and #{to_dir}..."
      @exec_helper.execute "sudo rsync -u -r -a  #{from_dir}/* #{to_dir}"
      @log.debug "Sync finished."
    end

    def cache_rpms( rpms )
      for name in rpms.keys
        cache_file = "#{@config.dir.src_cache}/#{name}"

        if ( ! File.exist?( cache_file ) )
          FileUtils.mkdir_p( @config.dir.src_cache )
          @exec_helper.execute( "wget #{rpms[name]} -O #{cache_file}" )
        end
      end
    end

    def create_devices( guestfs )
      @log.debug "Creating required devices..."
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x console" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x null" )
      guestfs.sh( "/sbin/MAKEDEV -d /dev -x zero" )
      @log.debug "Devices created."
    end

    def upload_fstab( guestfs )
      @log.debug "Uploading '/etc/fstab' file..."
      fstab_file = @image_config.is64bit? ? "#{File.dirname( __FILE__ )}/src/fstab_64bit" : "#{File.dirname( __FILE__ )}/src/fstab_32bit"
      guestfs.upload( fstab_file, "/etc/fstab" )
      @log.debug "'/etc/fstab' file uploaded."
    end

    # enable networking on default runlevels
    def enable_networking( guestfs )
      @log.debug "Enabling networking..."
      guestfs.sh( "/sbin/chkconfig network on" )
      guestfs.upload( "#{File.dirname( __FILE__ )}/src/ifcfg-eth0", "/etc/sysconfig/network-scripts/ifcfg-eth0" )
      @log.debug "Networking enabled."
    end

    def upload_rc_local( guestfs )
      @log.debug "Uploading '/etc/rc.local' file..."
      rc_local = Tempfile.new('rc_local')
      rc_local << guestfs.read_file( "/etc/rc.local" ) + File.read( "#{File.dirname( __FILE__ )}/src/rc_local" )
      rc_local.flush

      guestfs.upload( rc_local.path, "/etc/rc.local" )

      rc_local.close
      @log.debug "'/etc/rc.local' file uploaded."
    end

    def install_additional_packages( guestfs )
      rpms = {
              File.basename(AWS_DEFAULTS[:kernel_rpm][@image_config.hardware.arch]) => AWS_DEFAULTS[:kernel_rpm][@image_config.hardware.arch],
              "ec2-ami-tools.noarch.rpm" => "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.noarch.rpm"
      }

      cache_rpms( rpms )

      @log.debug "Installing additional packages (#{rpms.keys.join( ", " )})..."
      guestfs.mkdir_p("/tmp/rpms")

      for name in rpms.keys
        cache_file = "#{@config.dir.src_cache}/#{name}"
        guestfs.upload( cache_file, "/tmp/rpms/#{name}" )
      end

      guestfs.sh( "rpm -Uvh --nodeps /tmp/rpms/*.rpm" )
      guestfs.rm_rf("/tmp/rpms")
      @log.debug "Additional packages installed."
    end

    def change_configuration( guestfs )
      @log.debug "Changing configuration files using augeas..."
      guestfs.aug_init( "/", 0 )
      # disable password authentication
      guestfs.aug_set( "/files/etc/ssh/sshd_config/PasswordAuthentication", "no" )
      guestfs.aug_save
      @log.debug "Augeas changes saved."
    end

    def get_loop_device
      begin
        loop_device = @exec_helper.execute("sudo losetup -f 2>&1").strip
      rescue
        raise "No free loop devices available, please free at least one. See 'losetup -d' command."
      end

      loop_device
    end
  end
end