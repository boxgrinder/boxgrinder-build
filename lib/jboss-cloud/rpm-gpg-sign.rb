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

    def initialize( config, spec_file )
      @config     = config
      @spec_file  = spec_file
      @simple_name  = File.basename( @spec_file, ".spec" )

      define_tasks
    end

    def sign_rpm
      puts "Signing #{@simple_name} RPM..."

      @config.helper.validate_gpg_password

      release = nil
      version = nil
      is_noarch = nil

      Dir.chdir( File.dirname( @spec_file ) ) do
        release = `rpm --specfile #{@simple_name}.spec -q --qf '%{Release}\\n' 2> /dev/null`.split("\n").first
        version = `rpm --specfile #{@simple_name}.spec -q --qf '%{Version}\\n' 2> /dev/null`.split("\n").first
        is_noarch = `rpm --specfile #{@simple_name}.spec -q --qf '%{arch}\\n' 2> /dev/null`.split("\n").first == "noarch"
      end

      arch = is_noarch ? "noarch" : @config.build_arch

      `#{@config.dir.base}/extras/sign-rpms #{@config.data['gpg_password']} #{@config.dir.top}/#{@config.os_path}/RPMS/#{arch}/#{@simple_name}-#{version}-#{release}.#{arch}.rpm > /dev/null 2>&1`

      unless $?.to_i == 0
        puts "An error occured while signing #{@simple_name} package, check your passphrase"
      else
        puts "Package #{@simple_name} successfully signed!"
      end
    end

    def define_tasks
      task "rpm:#{@simple_name}:sign" => [ "rpm:#{@simple_name}" ] do
        sign_rpm
      end
    end
  end
end