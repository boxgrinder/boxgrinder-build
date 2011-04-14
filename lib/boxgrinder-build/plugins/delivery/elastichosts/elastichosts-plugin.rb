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
require 'restclient'
require 'json'
require 'zlib'

module BoxGrinder
  class ElasticHostsPlugin < BasePlugin
    def after_init
      set_default_config_value('chunk', 64) # chunk size in MB
      set_default_config_value('start_part', 0) # part number to start uploading
      set_default_config_value('wait', 5) # wait time before retrying upload
      set_default_config_value('retry', 3) # number of retries
      set_default_config_value('ssl', false) # use SSL?
      set_default_config_value('drive_name', @appliance_config.name)
    end

    def execute(type = :elastichosts)
      validate_plugin_config(['endpoint', 'user_uuid', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#ElasticHosts_Delivery_Plugin')

      raise PluginValidationError, "You can use ElasticHosts with base appliances (appliances created with operating system plugins) only, see http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#ElasticHosts_Delivery_Plugin." unless @previous_plugin_info[:type] == :os

      @log.info "Delivering appliance to ElasticHost..."

      upload

      @log.info "Appliance delivered to ElasticHost."
    end

    def disk_size
      size = 0
      @appliance_config.hardware.partitions.each_value { |partition| size += partition['size'] }
      size
    end

    def create_remote_disk
      size = disk_size

      @log.info "Creating new #{size} GB disk on ElasticHosts..."

      ret = RestClient.post(elastichosts_api_url('/drives/create'),
                            "{\"size\":#{size * 1024 *1024 * 1024},\"name\":\"#{@plugin_config['drive_name']}\"}",
                            :content_type => :json,
                            :accept => :json)

      @log.info "Disk created."

      JSON.parse(ret)['drive']
    end

    def elastichosts_api_url(path)
      "#{@plugin_config['ssl'] ? 'https' : 'http'}://#{@plugin_config['user_uuid']}:#{@plugin_config['secret_access_key']}@#{@plugin_config['endpoint']}#{path}"
    end

    def upload
      # Create the disk with specific size or use already existing
      @plugin_config['drive_uuid'] = create_remote_disk unless @plugin_config['drive_uuid']

      upload_chunks
    end

    def upload_chunks
      @step = @plugin_config['chunk'] * 1024 * 1024 # in bytes
      part = @plugin_config['start_part']

      @log.info "Uploading disk in #{disk_size * 1024 / @plugin_config['chunk']} parts."

      File.open(@previous_deliverables.disk, 'rb') do |f|
        while !f.eof?
          f.seek(part * @step, File::SEEK_SET)

          data = compress(f.read(@step))
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

      url = elastichosts_api_url("/drives/#{@plugin_config['drive_uuid']}/write/#{@step * part}")

      begin
        @log.info "Uploading part #{part+1}..."

        RestClient.post url,
                        data,
                        :accept => :json,
                        :content_type => "application/octet-stream",
                        'Content-Encoding' => 'gzip'

        @log.info "Part #{part+1} uploaded."
      rescue => e
        @log.warn "An error occured while uploading #{part} chunk, #{e.message}"
        try += 1

        unless try > @plugin_config['retry']
          # Let's sleep for specified amount of time
          sleep @plugin_config['wait']
          retry
        else
          raise PluginError, "Couldn't upload appliance, #{e.message}."
        end
      end
    end
  end
end

plugin :class => BoxGrinder::ElasticHostsPlugin, :type => :delivery, :name => :elastichosts, :full_name => "ElasticHosts"
