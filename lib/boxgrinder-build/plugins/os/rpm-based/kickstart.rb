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

require 'fileutils'
require 'yaml'
require 'erb'
require 'zlib'

module BoxGrinder

  class Kickstart
    def initialize(config, appliance_config, dir, options = {})
      @config           = config
      @appliance_config = appliance_config
      @dir              = dir
      @log              = options[:log] || Logger.new(STDOUT)

      @linux_helper     = LinuxHelper.new(:log => @log)

      @kickstart_file   = "#{@dir.tmp}/#{@appliance_config.name}.ks"
    end

    def create
      template = "#{File.dirname(__FILE__)}/src/appliance.ks.erb"
      kickstart = ERB.new(File.read(template)).result(build_definition.get_binding)
      File.open(@kickstart_file, 'w') { |f| f.write(kickstart) }

      @kickstart_file
    end

    def build_definition
      definition = {}

      definition['appliance_config']  = @appliance_config
      definition['repos']             = []
      definition['graphical']         = (@appliance_config.packages.include?( '@base-x' ) or @appliance_config.packages.include?( '@X Window System' )) ? true : false

      def definition.method_missing(sym, * args)
        self[sym.to_s]
      end

      def definition.get_binding
        binding
      end

      cost = 40

      definition['mount_points'] = @linux_helper.partition_mount_points(@appliance_config.hardware.partitions)

      for repo in @appliance_config.repos
        if repo.keys.include?('mirrorlist')
          urltype = 'mirrorlist'
        else
          urltype = 'baseurl'
        end

        substitutions = {
            /#ARCH#/        => @appliance_config.hardware.arch,
            /#BASE_ARCH#/   => @appliance_config.hardware.base_arch,
            /#OS_VERSION#/  => @appliance_config.os.version,
            /#OS_NAME#/     => @appliance_config.os.name
        }

        url   = repo[urltype]
        name  = repo['name']

        substitutions.each do |key, value|
          url   = url.gsub(key, value)
          name  = name.gsub(key, value)
        end

        definition['repos'] << "repo --name=#{name} --cost=#{cost} --#{urltype}=#{url}"

        cost += 1
      end
      
      definition
    end
  end
end
