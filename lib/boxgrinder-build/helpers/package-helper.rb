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

module BoxGrinder
  class PackageHelper
    def initialize(config, appliance_config, dir, options = {})
      @config           = config
      @appliance_config = appliance_config
      @dir              = dir

      @log              = options[:log] || Logger.new(STDOUT)
      @exec_helper      = options[:exec_helper] || ExecHelper.new({:log => @log})
    end

    def package(deliverables, package, type = :tar)
      files = []

      deliverables.each_value do |file|
        files << File.basename(file)
      end

      if File.exists?(package)
        @log.info "Package of #{type} type for #{@appliance_config.name} appliance already exists, skipping."
        return package
      end

      FileUtils.mkdir_p(File.dirname(package))

      @log.info "Packaging #{@appliance_config.name} appliance to #{type}..."

      case type
        when :tar
          @exec_helper.execute "tar -C #{File.dirname(deliverables[:disk])} -cvzf '#{package}' #{files.join(' ')}"
        else
          raise "Only tar format is currently supported."
      end

      @log.info "Appliance #{@appliance_config.name} packaged."

      package
    end
  end
end
