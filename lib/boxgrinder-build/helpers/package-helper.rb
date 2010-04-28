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
    def initialize( config, appliance_config, options = {} )
      @config           = config
      @appliance_config = appliance_config

      @log              = options[:log]         || Logger.new(STDOUT)
      @exec_helper      = options[:exec_helper] || ExecHelper.new( { :log => @log } )
    end

    def package( deliverables, type = :tar )


      files = []
      files << File.basename( deliverables[:disk] )

      [ :metadata, :other ].each do |deliverable_type|
        deliverables[deliverable_type].each_value do |file|
          files << File.basename(file)
        end
      end

      deliverable_platform  = deliverables[:platform].nil? ? "" : deliverables[:platform]
      package_path          = "#{@appliance_config.path.dir.packages}/#{@appliance_config.name}-#{@appliance_config.version}.#{@appliance_config.release}-#{@appliance_config.hardware.arch}-#{deliverable_platform}.tgz"

      if File.exists?( package_path )
         @log.info "Package of #{type} type for #{@appliance_config.name} appliance and #{deliverable_platform} platform already exists, skipping."


        return package_path
      end

      FileUtils.mkdir_p( File.dirname( package_path ) )

      @log.info "Packaging #{@appliance_config.name} appliance for #{deliverable_platform} platform to #{type}..."

      case type
        when :tar
          @exec_helper.execute "tar -C #{File.dirname( deliverables[:disk] )} -cvzf '#{package_path}' #{files.join(' ')}"
        else
          raise "Only tar format is currently supported."
      end

      @log.info "Appliance #{@appliance_config.name} packaged."

      package_path
    end
  end
end