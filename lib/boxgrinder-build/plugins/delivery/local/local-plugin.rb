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

require 'rubygems'
require 'boxgrinder-build/helpers/package-helper'
require 'boxgrinder-build/plugins/base-plugin'

module BoxGrinder
  class LocalPlugin < BasePlugin
    plugin :type => :delivery, :name => :local, :full_name  => "Local file system"

    def after_init
      @package_name = "#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}-#{@appliance_config.os.name}-#{@appliance_config.os.version}-#{@appliance_config.hardware.arch}-#{current_platform}.tgz"
    end

    def validate
      set_default_config_value('overwrite', false)
      set_default_config_value('package', true)

      validate_plugin_config(['path'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#Local_delivery_plugin')
    end

    def execute
      if @plugin_config['overwrite'] or !deliverables_exists?
        FileUtils.mkdir_p @plugin_config['path']

        if @plugin_config['package']
          PackageHelper.new(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).package(File.dirname(@previous_deliverables[:disk]), "#{@plugin_config['path']}/#{@package_name}") if @plugin_config['package']
        else
          @log.debug "Copying files to '#{@plugin_config['path']}'..."

          @previous_deliverables.each_value do |file|
            @log.debug "Copying '#{file}'..."
            @exec_helper.execute("cp '#{file}' '#{@plugin_config['path']}'")
          end
          @log.info "Appliance delivered to '#{@plugin_config['path']}'."
        end
      else
        @log.info "Appliance already delivered to '#{@plugin_config['path']}'."
      end
    end

    def deliverables_exists?      
      return File.exists?("#{@plugin_config['path']}/#{@package_name}") if @plugin_config['package']

      @previous_deliverables.each_value do |file|
        return false unless File.exists?("#{@plugin_config['path']}/#{File.basename(file)}")
      end

      @move_deliverables = false

      true
    end
  end
end

