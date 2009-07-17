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

require 'test/unit'
require 'jboss-cloud/appliance-image'

module JBossCloud

  class ApplianceImageTest < Test::Unit::TestCase
    def setup
      @options = { :log => LogMock.new, :exec_helper => ExecHelperMock.new }
      @appliance_image = ApplianceImage.new( ConfigHelper.generate_config, ConfigHelper.generate_appliance_config, @options )
      @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
    end

    def test_build_valid_appliance
      @appliance_image.build_raw_image

      assert_equal @options[:exec_helper].commands[0], "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t /tmp/dir_root/build/tmp --cache=rpms_cache/#{@current_arch}/#{APPLIANCE_DEFAULTS['os_name']}/#{APPLIANCE_DEFAULTS['os_version']} --config build/appliances/#{@current_arch}/#{APPLIANCE_DEFAULTS['os_name']}/#{APPLIANCE_DEFAULTS['os_version']}/valid-appliance/valid-appliance.ks -o build/appliances/#{@current_arch}/#{APPLIANCE_DEFAULTS['os_name']}/#{APPLIANCE_DEFAULTS['os_version']} --name valid-appliance --vmem 1024 --vcpu 1"

      assert_equal @options[:log].commands[0][:symbol], :info
      assert_equal @options[:log].commands[0][:args][0], "Building valid appliance..."

      assert_equal @options[:log].commands[1][:symbol], :info
      assert_equal @options[:log].commands[1][:args][0], "Appliance valid was built successfully."
    end
  end
end