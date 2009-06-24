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

module JBossCloud
  class Repodata < Rake::TaskLib

    def initialize( config, log )
      @config = config
      @log    = log

      @arches = SUPPORTED_ARCHES + [ "noarch" ]
      @oses   = SUPPORTED_OSES

      @exec_helper = ExecHelper.new( @log )

      define_tasks
    end

    def define_tasks
      desc "Force a rebuild of the repository data"
      task "rpm:repodata:force" => [ 'rpm:topdir' ] do
        createrepo
      end
    end

    def createrepo
      @log.debug "Refreshing repodata..."

      for os in @oses.keys
        for version in @oses[os]
          for arch in @arches
            @exec_helper.execute( "createrepo --update #{@config.dir.top}/#{os}/#{version}/RPMS/#{arch}" )
          end
        end
      end

      @log.debug "Refreshing repodata finished."
    end
  end
end
