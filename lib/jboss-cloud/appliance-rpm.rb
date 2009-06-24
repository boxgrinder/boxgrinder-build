#!/usr/bin/env ruby 

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

require 'jboss-cloud/rpm-gpg-sign'

module JBossCloud
  class ApplianceRPM < JBossCloud::RPM

    def initialize( config, appliance_config )
      @config            = config
      @appliance_config  = appliance_config

      @log          = LOG
      @exec_helper  = EXEC_HELPER

      define
    end

    def define
      appliance_build_dir   = "#{@config.dir_build}/#{@appliance_config.appliance_path}"
      spec_file             = "#{appliance_build_dir}/#{@appliance_config.name}.spec"
      simple_name           = File.basename( spec_file, ".spec" )
      rpm_file              = "#{@config.dir_top}/#{@appliance_config.os_path}/RPMS/noarch/#{simple_name}-#{@config.version_with_release}.noarch.rpm"

      JBossCloud::RPM.provides[simple_name] = "#{simple_name}-#{@config.version_with_release}"
      JBossCloud::RPMGPGSign.new( @config, spec_file, rpm_file )

      desc "Build #{simple_name} RPM."
      task "rpm:#{simple_name}"=>[ rpm_file ]

      file rpm_file => [ spec_file, "#{@config.dir_top}/#{@appliance_config.os_path}/SOURCES/#{simple_name}-#{@config.version}.tar.gz", 'rpm:topdir' ] do
        Dir.chdir( File.dirname( spec_file ) ) do
          @exec_helper.execute( "rpmbuild --define '_topdir #{@config.dir_root}/#{@config.dir_top}/#{@config.os_name}/#{@config.os_version}' --target noarch -ba #{simple_name}.spec" )
        end
        Rake::Task[ 'rpm:repodata:force' ].reenable
      end

      file rpm_file => [ 'rpm:vm2-support' ]
      file rpm_file => [ 'rpm:jboss-cloud-release' ]
      file rpm_file => [ 'rpm:jboss-cloud-management' ]

    end

  end
end
