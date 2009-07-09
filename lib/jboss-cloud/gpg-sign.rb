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
  class GPGSign < Rake::TaskLib

    def initialize( config )
      @config  = config

      @log          = LOG
      @exec_helper  = EXEC_HELPER

      define_tasks
    end

    def define_tasks
      task 'rpm:sign:all:srpms' => [ 'rpm:all' ] do
        sign_srpms
      end

      task 'rpm:sign:all:rpms' => [ 'rpm:all' ] do
        sing_rpms
      end

      desc "Sign all packages."
      task 'rpm:sign:all' => [ 'rpm:sign:all:rpms', 'rpm:sign:all:srpms' ]
    end

    def sign_srpms
      validate_and_sign( "#{@config.dir.base}/extras/sign-rpms #{@config.data['gpg_password']} #{@config.dir.top}/#{APPLIANCE_DEFAULTS['os_name']}/#{APPLIANCE_DEFAULTS['os_version']}/SRPMS/*.src.rpm > /dev/null 2>&1", "SRPMs" )
    end

    def sing_rpms
      validate_and_sign( "#{@config.dir.base}/extras/sign-rpms #{@config.data['gpg_password']} #{@config.dir.top}/#{@config.os_path}/RPMS/*/*.rpm > /dev/null 2>&1", "RPMs" )
    end

    def validate_and_sign( command, type )
      @log.info "Signing #{type}..."

      begin
        @config.helper.validate_gpg_password
        @exec_helper.execute( command )
      rescue => e
        @log.fatal "An error occured, some #{type} may be not signed. Possible errors: key exists?, wrong passphrase, expect package installed?, %_gpg_name in ~/.rpmmacros set?"
        raise e
      end

      @log.info "All #{type} were successfully signed!"
    end
  end
end