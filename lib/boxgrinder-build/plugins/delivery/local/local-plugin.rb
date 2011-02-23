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
    def after_init
      set_default_config_value('overwrite', false)
      set_default_config_value('package', true)

      if @plugin_config['package']
        register_deliverable(:package => "#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}-#{@appliance_config.os.name}-#{@appliance_config.os.version}-#{@appliance_config.hardware.arch}-#{current_platform}.tgz")
      end
    end

    def execute(type = :local)
      validate_plugin_config(['path'], 'http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#Local_delivery_plugin')

      if @plugin_config['overwrite'] or !deliverables_exists?
        PackageHelper.new(@config, @appliance_config, :log => @log, :exec_helper => @exec_helper).package(File.dirname(@previous_deliverables[:disk]), @deliverables[:package]) if @plugin_config['package']

        FileUtils.mkdir_p @plugin_config['path']

        @log.debug "Copying files to '#{@plugin_config['path']}'..."

        (@plugin_config['package'] ? @deliverables : @previous_deliverables).each_value do |file|
          @log.debug "Copying '#{file}'..."
          @exec_helper.execute("cp '#{file}' '#{@plugin_config['path']}'")
        end
        @log.info "Appliance delivered to '#{@plugin_config['path']}'."
      else
        @log.info "Appliance already delivered to '#{@plugin_config['path']}'."
      end
    end

    def deliverables_exists?
      (@plugin_config['package'] ? @deliverables : @previous_deliverables).each_value do |file|
        return false unless File.exists?("#{@plugin_config['path']}/#{File.basename(file)}")
      end

      @move_deliverables = false

      true
    end
  end
end
