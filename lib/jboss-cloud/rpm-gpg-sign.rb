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
  class RPMGPGSign < Rake::TaskLib

    def initialize( config, spec_file, rpm_file )
      @config           = config
      @spec_file        = spec_file

      @rpm_file         = rpm_file

      @rpm_file_basename  = File.basename( @rpm_file )
      @simple_name        = File.basename( @spec_file, ".spec" )

      @log          = LOG
      @exec_helper  = EXEC_HELPER

      define_tasks
    end

    def define_tasks
      task "rpm:#{@simple_name}:sign" => [ "rpm:#{@simple_name}" ] do
        sign_rpm
      end
    end

    def sign_rpm
      @log.info "Signing package '#{@rpm_file_basename}'..."

      @config.helper.validate_gpg_password
      out = @exec_helper.execute( "#{@config.dir.base}/extras/sign-rpms #{@config.data['gpg_password']} #{@rpm_file}" )

      raise "An error occured. Possible errors: key exists?, wrong passphrase, expect package installed?, %_gpg_name in ~/.rpmmacros set?" if out =~ /Pass phrase check failed/

      @log.info "Package '#{@rpm_file_basename}' successfully signed!"
    end
  end
end