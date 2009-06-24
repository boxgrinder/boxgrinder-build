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

require 'rake/tasklib'
require 'jboss-cloud/repodata'

module JBossCloud
  class Topdir < Rake::TaskLib

    def initialize( config, log )
      @config = config
      @log    = log

      @topdir = @config.dir_top
      @arches = SUPPORTED_ARCHES + [ "noarch" ]
      @oses   = SUPPORTED_OSES

      Repodata.new( @config, @log )

      define_tasks
    end

    def define_tasks

      for os in @oses.keys
        for version in @oses[os]
          directory "#{@topdir}/#{os}/#{version}/tmp"
          directory "#{@topdir}/#{os}/#{version}/SPECS"
          directory "#{@topdir}/#{os}/#{version}/SOURCES"
          directory "#{@topdir}/#{os}/#{version}/BUILD"
          directory "#{@topdir}/#{os}/#{version}/RPMS"
          directory "#{@topdir}/#{os}/#{version}/SRPMS"

          task "rpm:topdir" => [
                  "#{@topdir}/#{os}/#{version}/tmp",
                  "#{@topdir}/#{os}/#{version}/SPECS",
                  "#{@topdir}/#{os}/#{version}/SOURCES",
                  "#{@topdir}/#{os}/#{version}/BUILD",
                  "#{@topdir}/#{os}/#{version}/RPMS",
                  "#{@topdir}/#{os}/#{version}/SRPMS",
          ]

          for arch in @arches
            directory "#{@topdir}/#{os}/#{version}/RPMS/#{arch}"

            task "rpm:topdir" => [ "#{@topdir}/#{os}/#{version}/RPMS/#{arch}" ]
          end
        end
      end
    end
  end
end
