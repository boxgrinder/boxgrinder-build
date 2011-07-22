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

require 'boxgrinder-build/plugins/base-plugin'
require 'rubygems'
require 'restclient'
require 'zlib'
require 'cgi'

module BoxGrinder
  class ElasticHostsPlugin < BasePlugin
    def validate
      set_default_config_value('chunk', 64) # chunk size in MB
      set_default_config_value('start_part', 0) # part number to start uploading
      set_default_config_value('wait', 5) # wait time before retrying upload
      set_default_config_value('retry', 3) # number of retries
      set_default_config_value('ssl', false) # use SSL?
      set_default_config_value('drive_name', @appliance_config.name)

      validate_plugin_config(['endpoint', 'username', 'password'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#ElasticHosts_Delivery_Plugin')
      raise PluginValidationError, "You can use ElasticHosts plugin with base appliances (appliances created with operating system plugins) only, see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#ElasticHosts_Delivery_Plugin." unless @previous_plugin_info[:type] == :os
    end

    def execute
      upload
      create_server
    end

    def disk_size
      size = 0
      @appliance_config.hardware.partitions.each_value { |partition| size += partition['size'] }
      size
    end

    def hash_to_request(h)
      body = ""

      h.each do |k, v|
        body << "#{k} #{v.to_s}\n"
      end

      body
    end

    def response_to_hash(r)
      h = {}

      r.each_line do |l|
        h[$1] = $2 if l =~ /(\w+) (.*)/
      end

      h
    end

    def create_remote_disk
      size = disk_size

      @log.info "Creating new #{size} GB disk..."


      body = hash_to_request(
          'size' => size * 1024 *1024 * 1024,
          'name' => @plugin_config['drive_name']
      )

      begin
        ret = response_to_hash(RestClient.post(api_url('/drives/create'), body))


        @log.info "Disk created with UUID: #{ret['drive']}."
      rescue => e
        @log.error e.info
        raise PluginError, "An error occured while creating the drive, #{e.message}. See logs for more info."
      end

      ret['drive']
    end

    def api_url(path)
      "#{@plugin_config['ssl'] ? 'https' : 'http'}://#{CGI.escape(@plugin_config['username'])}:#{@plugin_config['password']}@#{@plugin_config['endpoint']}#{path}"
    end

    def upload
      @log.info "Uploading appliance..."

      # Create the disk with specific size or use already existing
      @plugin_config['drive_uuid'] = create_remote_disk unless @plugin_config['drive_uuid']

      upload_chunks

      @log.info "Appliance uploaded."
    end

    def upload_chunks
      @step = @plugin_config['chunk'] * 1024 * 1024 # in bytes
      part = @plugin_config['start_part']

      @log.info "Uploading disk in #{disk_size * 1024 / @plugin_config['chunk']} parts."

      File.open(@previous_deliverables.disk, 'rb') do |f|
        while !f.eof?
          f.seek(part * @step, File::SEEK_SET)

          data = f.read(@step)
          data = compress(data) unless is_cloudsigma?
          upload_chunk(data, part)

          part += 1
        end
      end

      @log.info "Appliance #{@appliance_config.name} uploaded to drive with UUID #{@plugin_config['drive_uuid']}."
    end

    def compress(data)
      @log.trace "Compressing #{data.size / 1024} kB chunk of data..."

      io = StringIO.new

      writer = Zlib::GzipWriter.new(io, Zlib::DEFAULT_COMPRESSION, Zlib::FINISH)
      writer.write(data)
      writer.close

      @log.trace "Data compressed to #{io.size / 1024} kB."

      io.string
    end

    def upload_chunk(data, part)
      try = 1

      url = api_url("/drives/#{@plugin_config['drive_uuid']}/write/#{@step * part}")

      begin
        @log.info "Uploading part #{part+1}..."

        headers = {:content_type => "application/octet-stream"}
        headers['Content-Encoding'] = 'gzip' unless is_cloudsigma?

        RestClient.post url,
                        data,
                        headers

        @log.info "Part #{part+1} uploaded."
      rescue => e
        @log.warn "An error occured while uploading #{part} chunk, #{e.message}"
        try += 1

        unless try > @plugin_config['retry']
          # Let's sleep for specified amount of time
          sleep @plugin_config['wait']
          retry
        else
          @log.error e.info
          raise PluginError, "Couldn't upload appliance, #{e.message}."
        end
      end
    end

    def is_cloudsigma?
      !@plugin_config['endpoint'].match(/cloudsigma\.com$/).nil?
    end

    # Creates the server for previously uploaded disk
    def create_server
      @log.info "Creating new server..."

      memory = ((is_cloudsigma? and @appliance_config.hardware.memory < 512) ? 512 : @appliance_config.hardware.memory)

      body = hash_to_request(
          'name' => "#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}",
          'cpu' => @appliance_config.hardware.cpus * 1000, # MHz
          'smp' => 'auto',
          'mem' => memory,
          'persistent' => 'true', # hack
          'ide:0:0' => @plugin_config['drive_uuid'],
          'boot' => 'ide:0:0',
          'nic:0:model' => 'e1000',
          'nic:0:dhcp' => 'auto',
          'vnc:ip' => 'auto',
          'vnc:password' => (0...8).map { (('a'..'z').to_a + ('A'..'Z').to_a)[rand(52)] }.join # 8 character VNC password
      )

      begin
        path = is_cloudsigma? ? '/servers/create' : '/servers/create/stopped'
        ret = response_to_hash(RestClient.post(api_url(path), body))

        @log.info "Server was registered with '#{ret['name']}' name as '#{ret['server']}' UUID. Use web UI or API tools to start your server."
      rescue => e
        @log.error e.info
        raise PluginError, "An error occured while creating the server, #{e.message}. See logs for more info."
      end
    end
  end
end

plugin :class => BoxGrinder::ElasticHostsPlugin, :type => :delivery, :name => :elastichosts, :full_name => "ElasticHosts"
