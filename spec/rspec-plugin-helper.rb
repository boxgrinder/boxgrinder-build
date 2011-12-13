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

class RSpecPluginHelper
  def initialize(clazz, options = {})
    @options = { :skip => [] }.merge(options)
    @clazz = clazz
  end

  def prepare(config, appliance_config, options = {})
    options = {
      :skip => [],
      :log => BoxGrinder::LogHelper.new(:level => :trace, :type => :stdout)
    }.merge(options)

    config.stub!(:file).and_return('boxgrinder/configuration/file')

    plugin = @clazz.new

    yield plugin if block_given?

    plugin.init(config, appliance_config, options[:plugin_info], options)

    ([:after_init, :validate, :after_validate] - @options[:skip]).each do |callback|
      plugin.send(callback) if plugin.respond_to?(callback)
    end

    plugin
  end
end
