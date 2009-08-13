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

require 'jboss-cloud/defaults'
require 'jboss-cloud/helpers/config-helper'
require 'ostruct'
require 'jboss-cloud/model/release'

module JBossCloud
  class ApplianceConfig
    def initialize( name, arch, os_name, os_version )
      @name = name
      @arch = arch
      @os_name = os_name
      @os_version = os_version

      @packages   = []
      @gems       = []
      @repos      = {}

      @appliances = Array.new

      @path       = OpenStruct.new

      @path.dir   = OpenStruct.new
      @path.file  = OpenStruct.new

      @path.file.xml    = "build/#{appliance_path}/#{@name}.xml"
      @path.file.raw    = "build/#{appliance_path}/#{@name}-sda.raw"
      @path.file.ec2    = "build/#{appliance_path}/#{@name}.ec2"
    end

    attr_reader :name
    attr_reader :arch
    attr_reader :os_name
    attr_reader :os_version
    attr_reader :path

    attr_accessor :vcpu
    attr_accessor :mem_size
    attr_accessor :disk_size
    attr_accessor :network_name
    attr_accessor :output_format
    attr_accessor :appliances
    attr_accessor :summary
    attr_accessor :packages
    attr_accessor :repos

    # used to checking if configuration diffiers from previous in appliance-kickstart

    def hash
      # without output_format!
      "#{@name}-#{@arch}-#{@os_name}-#{@os_version}-#{@vcpu}-#{@mem_size}-#{@disk_size}-#{@network_name}-#{@appliances.join("-")}-#{@summary}".hash
    end

    def simple_name
      File.basename( @name, '-appliance' )
    end

    def os_path
      "#{@os_name}/#{@os_version}"
    end

    def main_path
      "#{@arch}/#{os_path}"
    end

    def appliance_path
      "appliances/#{main_path}/#{@name}"
    end

    def eql?(other)
      hash == other.hash
    end

    def is64bit?
      @arch.eql?("x86_64")
    end

    def is_development?
      return true if @os_name.eql?("fedora") and @os_version.eql?("rawhide")

      false
    end

  end
  class Config
    def initialize( name, version, release, dir, config_file )
      @name             = name
      @dir              = dir
      @config_file      = config_file

      # TODO better way to get this directory
      @dir.base         = "#{File.dirname( __FILE__ )}/../.."
      @dir.tmp          = "#{@dir.build}/tmp"

      @files            = OpenStruct.new

      @version          = OpenStruct.new
      @version.version  = version
      @version.release  = release

      @dir_rpms_cache   = @dir.rpms_cache
      @dir_src_cache    = @dir.src_cache
      @dir_root         = @dir.root
      @dir_top          = @dir.top
      @dir_build        = @dir.build
      @dir_specs        = @dir.specs
      @dir_appliances   = @dir.appliances
      @dir_src          = @dir.src
      @dir_kickstarts   = @dir.kickstarts

      @aws                = OpenStruct.new
      @aws.bucket_prefix  = "#{@name.downcase.gsub!(" ", "-")}/#{version_with_release}"

      @dir_base         = @dir.base

      @data = {}

      if File.exists?( @config_file )
        @data = YAML.load_file( @config_file )
        @data['gpg_password'].gsub!(/\$/, "\\$") unless @data['gpg_password'].nil? or @data['gpg_password'].length == 0
      end

      @release          = Release.new( self )

      @arch             = (-1.size) == 8 ? "x86_64" : "i386"

      # it's save, we have validated it before
      @build_arch       = ENV['JBOSS_CLOUD_ARCH'].nil? ? @arch : ENV['JBOSS_CLOUD_ARCH']
      @os_name          = ENV['JBOSS_CLOUD_OS_NAME'].nil? ? APPLIANCE_DEFAULTS['os_name'] : ENV['JBOSS_CLOUD_OS_NAME']
      @os_version       = ENV['JBOSS_CLOUD_OS_VERSION'].nil? ? APPLIANCE_DEFAULTS['os_version'] : ENV['JBOSS_CLOUD_OS_VERSION']

      @helper           = JBossCloud::ConfigHelper.new( self )
    end

    attr_reader :name
    attr_reader :version
    attr_reader :release
    attr_reader :build_arch
    attr_reader :arch
    attr_reader :dir_rpms_cache
    attr_reader :dir_src_cache
    attr_reader :dir_root
    attr_reader :dir_top
    attr_reader :dir_build
    attr_reader :dir_specs
    attr_reader :dir_appliances
    attr_reader :dir_src
    attr_reader :dir_base
    attr_reader :os_name
    attr_reader :os_version
    attr_reader :dir_kickstarts
    attr_reader :data
    attr_reader :helper
    attr_reader :config_file
    attr_reader :aws

    attr_reader :dir
    attr_reader :files

    def os_path
      "#{@os_name}/#{@os_version}"
    end

    def build_path
      "#{@arch}/#{os_path}"
    end

    def version_with_release
      @version.version + ((@version.release.nil? or @version.release.empty?) ? "" : "-" + @version.release)
    end
  end
end
