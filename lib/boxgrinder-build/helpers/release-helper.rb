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
require 'boxgrinder-core/validators/errors'
require 'boxgrinder-build/validators/ssh-validator'

# TODO this needs to be moved to selected plugins
module BoxGrinder
  class ReleaseHelper < Rake::TaskLib
    def initialize( config, appliance_config, options = {} )
      @config = config
      @appliance_config = appliance_config

      @log          = options[:log]         || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new( { :log => @log } )

      @package_build_commands = {
              :raw => {
                      :tgz => "tar -C #{@appliance_config.path.dir.raw.build_full} -cvzf #{@appliance_config.path.file.package[:raw][:tgz]} #{@appliance_config.name}-sda.raw #{@appliance_config.name}.xml",
                      :zip => "cd #{@appliance_config.path.dir.raw.build_full} && zip -r #{Dir.pwd}/#{@appliance_config.path.file.package[:raw][:zip]} ."
              },
              :vmware => {
                      :tgz => "tar -C #{@appliance_config.path.dir.vmware.build} -cvzf '#{@appliance_config.path.file.package[:vmware][:tgz]}' README #{@appliance_config.name}-sda.raw personal/#{@appliance_config.name}.vmx personal/#{@appliance_config.name}.vmdk enterprise/#{@appliance_config.name}.vmx enterprise/#{@appliance_config.name}.vmdk",
                      :zip => "cd #{@appliance_config.path.dir.vmware.build} && zip #{Dir.pwd}/#{@appliance_config.path.file.package[:vmware][:zip]} README #{@appliance_config.name}-sda.raw personal/#{@appliance_config.name}.vmx personal/#{@appliance_config.name}.vmdk enterprise/#{@appliance_config.name}.vmx enterprise/#{@appliance_config.name}.vmdk"
              }
      }

      @base_remote_file_path = "#{@config.version_with_release}/#{@appliance_config.hardware.arch}"

      define_tasks
    end

    def define_tasks

      directory @appliance_config.path.dir.packages

      [ :tgz, :zip ].each do |package_format|
        task "appliance:#{@appliance_config.name}:package:#{package_format}" => [ @appliance_config.path.file.package[:raw][package_format], @appliance_config.path.file.package[:vmware][package_format] ]

        [ :vmware, :raw ].each do |image_format|
          basename = File.basename( @appliance_config.path.file.package[image_format][package_format] )
          files_to_upload = { "#{@appliance_config.name}/#{@appliance_config.version}.#{@appliance_config.release}/#{@appliance_config.hardware.arch}/#{basename}" => @appliance_config.path.file.package[image_format][package_format] }

          desc "Create #{image_format.to_s.upcase} #{package_format.to_s.upcase} package for #{@appliance_config.simple_name} appliance"
          task "appliance:#{@appliance_config.name}:package:#{image_format}:#{package_format}" => [ @appliance_config.path.file.package[image_format][package_format] ]

          file @appliance_config.path.file.package[image_format][package_format] => [ @appliance_config.path.dir.packages, "appliance:#{@appliance_config.name}" ] do
            @log.info "Packaging #{@appliance_config.name} appliance #{image_format.to_s.upcase} image (#{@appliance_config.os.name} #{@appliance_config.os.version}, #{@appliance_config.hardware.arch} arch, #{package_format.to_s.upcase} format)..."

            Rake::Task[ "#{@appliance_config.path.dir.vmware.build}/README" ].invoke if image_format.eql?(:vmware)

            @exec_helper.execute @package_build_commands[image_format][package_format]
            @log.info "#{image_format.to_s.upcase} #{package_format.to_s.upcase} package created."
          end

          task "appliance:#{@appliance_config.name}:upload:#{image_format}:#{package_format}:ssh" => [ "appliance:#{@appliance_config.name}:package:#{image_format}:#{package_format}" ] do
            upload_via_ssh( files_to_upload )
          end

          task "appliance:#{@appliance_config.name}:upload:#{image_format}:#{package_format}:cloudfront" => [ "appliance:#{@appliance_config.name}:package:#{image_format}:#{package_format}" ] do
            upload_to_cloudfront( files_to_upload )
          end
        end
      end

      file "#{@appliance_config.path.dir.vmware.build}/README" => [ "appliance:#{@appliance_config.name}:vmware:personal", "appliance:#{@appliance_config.name}:vmware:enterprise" ] do
        readme = File.open( "#{@config.dir.base}/src/README.vmware" ).read

        readme.gsub!( /#APPLIANCE_NAME#/, @appliance_config.name )
        readme.gsub!( /#NAME#/, @config.name )
        readme.gsub!( /#VERSION#/, @config.version_with_release )

        File.open( "#{@appliance_config.path.dir.vmware.build}/README", "w") {|f| f.write( readme ) }
      end

    end

    def upload_via_ssh( files )
      @log.info "Uploading #{@appliance_config.name} appliance via SSH..."

      SSHValidator.new( @config ).validate

      ssh_config = SSHConfig.new( @config )

      ssh_helper = SSHHelper.new( ssh_config.options, { :log => @log } )
      ssh_helper.connect
      ssh_helper.upload_files( ssh_config.cfg['remote_release_path'], files )
      ssh_helper.disconnect

      @log.info "Appliance #{@appliance_config.simple_name} uploaded."
    end

    def upload_to_cloudfront( files )
      AWSHelper.new( @config, @appliance_config )

      bucket = @config.data['release']['cloudfront']['bucket_name']

      @log.info "Uploading #{@appliance_config.name} appliance to CloudFront bucket '#{bucket}'..."

      begin
        AWS::S3::Bucket.find( bucket )
      rescue AWS::S3::NoSuchBucket
        AWS::S3::Bucket.create( bucket )
        retry
      end

      for key in files.keys
        unless S3Object.exists?( key, bucket )
          AWS::S3::S3Object.store( key, open( files[key] ), bucket, :access => :public_read )
        end
      end

      @log.info "Appliance #{@appliance_config.simple_name} uploaded."
    end
  end
end

