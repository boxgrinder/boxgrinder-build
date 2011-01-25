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

require 'boxgrinder-core/helpers/log-helper'

module BoxGrinder
  class PackageHelper
    def initialize(config, appliance_config, options = {})
      @config = config
      @appliance_config = appliance_config

      @log = options[:log] || LogHelper.new
      @exec_helper = options[:exec_helper] || ExecHelper.new(:log => @log)
    end

    def package(dir, package, type = :tar)
      if File.exists?(package)
        @log.info "Package of #{type} type for #{@appliance_config.name} appliance already exists, skipping."
        return package
      end

      @log.info "Packaging #{@appliance_config.name} appliance to #{type}..."

      case type
        when :tar
          package_name = File.basename(package, '.tgz')
          symlink = "#{File.dirname(package)}/#{package_name}"

          FileUtils.ln_s(File.expand_path(dir), symlink)
          @exec_helper.execute "tar -C '#{File.dirname(package)}' -hcvzf '#{package}' '#{package_name}'"
          FileUtils.rm(symlink)
        else
          raise "Specified format: '#{type}' is currently unsupported."
      end

      @log.info "Appliance #{@appliance_config.name} packaged."

      package
    end
  end
end
