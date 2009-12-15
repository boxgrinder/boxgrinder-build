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
require 'boxgrinder/helpers/config-helper'
require 'ostruct'
require 'boxgrinder/model/release'

module BoxGrinder
  class ApplianceConfig
    def initialize( definition )
      @definition = definition[:definition]
      @file = definition[:file]

      @name = @definition['name']
      @summary = @definition['summary']

      @os = OpenStruct.new
      @os.name = ENV['BG_OS_NAME'].nil? ? APPLIANCE_DEFAULTS[:os][:name] : ENV['BG_OS_NAME']
      @os.version = ENV['BG_OS_VERSION'].nil? ? APPLIANCE_DEFAULTS[:os][:version] : ENV['BG_OS_VERSION']
      @os.password = ENV['BG_OS_PASSWORD'].nil? ? APPLIANCE_DEFAULTS[:os][:password] : ENV['BG_OS_PASSWORD']

      @hardware = OpenStruct.new

      @hardware.arch = APPLIANCE_DEFAULTS[:hardware][:arch]
      @hardware.cpus = ENV['BG_HARDWARE_CPUS'].nil? ? 0 : ENV['BG_HARDWARE_CPUS'].to_i
      @hardware.memory = 0
      @hardware.network = APPLIANCE_DEFAULTS[:hardware][:network]

      @post = OpenStruct.new

      @post.base = []
      @post.ec2 = []
      @post.vmware = []

      @appliances = []
      @repos = []
      @packages = []
      @version = 1
      @release = 0

      @path = OpenStruct.new

      @path.dir = OpenStruct.new
      @path.file = OpenStruct.new
      @path.file.raw = OpenStruct.new

      @path.dir.build = OpenStruct.new

      @path.dir.build.raw = "build/#{appliance_path}/raw"
      @path.dir.build.ec2 = "build/#{appliance_path}/ec2"

      @path.file.raw.kickstart = "#{@path.dir.build.raw}/#{@name}.ks"
      @path.file.raw.config = "#{@path.dir.build.raw}/#{@name}.cfg"
      @path.file.raw.yum = "#{@path.dir.build.raw}/#{@name}.yum.conf"
      @path.file.raw.disk = "#{@path.dir.build.raw}/#{@name}/#{@name}-sda.raw"
      @path.file.raw.xml = "#{@path.dir.build.raw}/#{@name}/#{@name}.xml"

      @path.file.ec2 = "#{@path.dir.build.ec2}/#{@name}.ec2"
    end

    attr_reader :definition
    attr_reader :name
    attr_reader :summary
    attr_reader :appliances
    attr_reader :os
    attr_reader :hardware
    attr_reader :repos
    attr_reader :packages
    attr_reader :path
    attr_reader :file

    attr_accessor :version
    attr_accessor :release
    attr_accessor :post

    # used to checking if configuration diffiers from previous in appliance-kickstart
    def hash
      "#{@name}-#{@summary}-#{@version}-#{@release}-#{@os.name}-#{@os.version}-#{@os.password}-#{@hardware.cpus}-#{@hardware.memory}-#{@hardware.partitions}-#{@appliances.join("-")}".hash
    end

    def simple_name
      @name
    end

    def os_path
      "#{@os.name}/#{@os.version}"
    end

    def main_path
      "#{@hardware.arch}/#{os_path}"
    end

    def appliance_path
      "appliances/#{main_path}/#{@name}"
    end

    def eql?(other)
      hash.eql?(other.hash)
    end

    def is64bit?
      @hardware.arch.eql?("x86_64")
    end

    def is_os_version_stable?
      DEVELOPMENT_RELEASES[@os.name].eql?(@os.version)
    end
  end

  class Config
    def initialize( name, version, release, dir, config_file )
      @name = name
      @dir = dir
      @config_file = config_file

      # TODO better way to get this directory
      @dir.base = "#{File.dirname( __FILE__ )}/../.."
      @dir.tmp = "#{@dir.build}/tmp"

      @files = OpenStruct.new

      @version = OpenStruct.new
      @version.version = version
      @version.release = release

      @dir_rpms_cache = @dir.rpms_cache
      @dir_src_cache = @dir.src_cache
      @dir_root = @dir.root
      @dir_top = @dir.top
      @dir_build = @dir.build
      @dir_specs = @dir.specs
      @dir_appliances = @dir.appliances
      @dir_src = @dir.src
      @dir_kickstarts = @dir.kickstarts

      @aws = OpenStruct.new
      @aws.bucket_prefix = "#{@name.downcase.gsub(" ", "-")}/#{version_with_release}"

      @dir_base = @dir.base

      @data = {}

      if File.exists?( @config_file )
        @data = YAML.load_file( @config_file )
        @data['gpg_password'].gsub!(/\$/, "\\$") unless @data['gpg_password'].nil? or @data['gpg_password'].length == 0
      end

      @release = Release.new( self )

      @arch = (-1.size) == 8 ? "x86_64" : "i386"

      # it's save, we have validated it before
      @build_arch = ENV['BG_HARDWARE_ARCH'].nil? ? @arch : ENV['BG_HARDWARE_ARCH']
      @os_name = ENV['BG_OS_NAME'].nil? ? APPLIANCE_DEFAULTS[:os][:name] : ENV['BG_OS_NAME']
      @os_version = ENV['BG_OS_VERSION'].nil? ? APPLIANCE_DEFAULTS[:os][:version] : ENV['BG_OS_VERSION']

      @helper = ConfigHelper.new( self )
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
