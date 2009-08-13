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
        @log.warn "Specified configuration file (#{@config.config_file}) doesn't exists."
        return nil
      end

      #raise ValidationError, "Specified configuration file (#{@config.config_file}) doesn't exists. #{DEFAULT_HELP_TEXT[:general]}" unless File.exists?( @config.config_file )

      @release = @config.data['release']

      if @release.nil?
        @log.warn "No 'release' section in configuration file '#{@config.config_file}'."
        return nil
      end

      #raise ValidationError, "No 'release' section in configuration file '#{@config.config_file}'. #{DEFAULT_HELP_TEXT[:general]}" if @release.nil?

      @appliances = @release['appliances']

      if @appliances.nil? or @appliances.size == 0
        @log.warn "No appliances specified for release, all appliances will be used."

        @appliances = []

        Dir[ "#{@config.dir_appliances}/*/*.appl" ].each do |appliance_def|
          @appliances << File.basename( appliance_def, '.appl' )
        end
      end

      @log.debug "Added #{@appliances.size} appliances to release list (#{@appliances.join( ", " )})."
    end

    attr_reader :release
    attr_reader :appliances

  end
end