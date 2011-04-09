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
      set_default_config_value('chunk', 64)
      set_default_config_value('drive_name', @appliance_config.name)
    end

    def execute(type = :elastichosts)
      validate_plugin_config(['endpoint', 'user_uuid', 'secret_access_key'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#ElasticHosts_Delivery_Plugin')

      raise "You can use ElasticHosts with base appliances created with operating system plugins only." unless @previous_plugin_info[:type] == :os

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
                            {
                                :name => @plugin_config['drive_name'],
                                :size => size * 1024 *1024 * 1024
                            }.to_json,
                            :content_type => :json,
                            :accept => :json)

      @log.info "Disk created."

      JSON.parse(ret)['drive']
    end

    def elastichosts_api_url(path)
      "https://#{@plugin_config['user_uuid']}:#{@plugin_config['secret_access_key']}@#{@plugin_config['endpoint']}#{path}"
    end

    def upload
      # Create the disk on ElasticHosts with specific size
      @plugin_config['drive_uuid'] = create_remote_disk unless @plugin_config['drive_uuid']

      mb = @plugin_config['chunk']
      step = mb * 1024 * 1024 # in bytes
      part = 0

      @log.info "Uploading disk in #{disk_size * 1024 / mb} parts."

      File.open(@previous_deliverables.disk, 'rb') do |f|
        while !f.eof?
          f.seek(part * step, File::SEEK_SET)

          data = f.read(step)

          io = StringIO.new

          writer = Zlib::GzipWriter.new(io)
          writer.write(data)
          writer.close

          compressed_data = io.string

          @log.trace "Compressed data size to upload for part #{part+1}: #{compressed_data.length / 1024} kB."
          @log.debug "Uploading #{part+1} part..."

          RestClient.post elastichosts_api_url("/drives/#{@plugin_config['drive_uuid']}/write/#{step * part}"),
                          compressed_data,
                          :accept => :json,
                          :content_type => "application/octet-stream",
                          'Content-Encoding' => 'gzip'

          part += 1
        end
      end

      @log.info "Appliance #{@appliance_config.name} uploaded to drive with UUID #{@plugin_config['drive_uuid']}."
    end
  end
end

plugin :class => BoxGrinder::ElasticHostsPlugin, :type => :delivery, :name => :elastichosts, :full_name => "ElasticHosts"
