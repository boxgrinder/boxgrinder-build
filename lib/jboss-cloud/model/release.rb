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

module JBossCloud
  class Release
    def initialize( config, options = {} )
      @config = config
      @log    = options[:log] || LOG

      validate
    end

    def validate
      unless File.exists?( @config.config_file )
        #@log.warn "Specified configuration file (#{@config.config_file}) doesn't exists."
        return nil
      end

      @release = @config.data['release']

      if @release.nil?
        #@log.warn "No 'release' section in configuration file '#{@config.config_file}'."
        return nil
      end

      @appliances = @release['appliances']

      if @appliances.nil? or @appliances.size == 0
        @log.warn "No appliances specified for release, all appliances will be used."

        @appliances = []

        Dir[ "#{@config.dir_appliances}/*/*.appl" ].each do |appliance_def|
          @appliances << File.basename( appliance_def, '.appl' )
        end
      end

      @ssh        = @release['ssh'] unless @release['ssh'].nil?
      @cloudfront = @release['cloudfront'] unless @release['cloudfront'].nil?
      @s3         = @release['s3'] unless @release['s3'].nil?

      @default_type = @release['default_type']

      unless @default_type.nil?
        @connection_data = @release[@default_type]
        raise ValidationError, "You specified '#{@default_type}' type in release section in your config file, but there is no '#{@default_type}' subsection, please correct this." if @release[@default_type].nil?
      else
        @default_type = 'ssh'
        @connection_data = @ssh
      end

      @log.debug "Added #{@appliances.size} appliances to release list (#{@appliances.join( ", " )})."
    end

    attr_reader :release
    attr_reader :appliances
    attr_reader :default_type
    attr_reader :ssh
    attr_reader :s3
    attr_reader :cloudfront
    attr_reader :connection_data

  end
end