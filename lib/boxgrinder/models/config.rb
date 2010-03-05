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

require 'boxgrinder/defaults'
require 'ostruct'
require 'rbconfig'

module BoxGrinder
  class Config
    def initialize( name, version, release, dir, config_file )
      @name         = name
      @dir          = dir
      @config_file  = config_file

      # TODO better way to get this directory
      @dir.base = "#{File.dirname( __FILE__ )}/../../../"

      @version = OpenStruct.new
      @version.version = version
      @version.release = release

      @files = OpenStruct.new
      @data = {}

      if File.exists?( @config_file )
        @data = YAML.load_file( @config_file )
        @data['gpg_password'].gsub!(/\$/, "\\$") unless @data['gpg_password'].nil? or @data['gpg_password'].length == 0
      end
    end

    attr_reader :name
    attr_reader :version
    attr_reader :release
    attr_reader :data
    attr_reader :config_file
    attr_reader :dir
    attr_reader :files

    def version_with_release
      @version.version + ((@version.release.nil? or @version.release.empty?) ? "" : "-" + @version.release)
    end
  end
end
