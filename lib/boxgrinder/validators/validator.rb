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

require 'boxgrinder/config'
require 'boxgrinder/validators/errors'
require 'boxgrinder/validators/appliance-validator'
require 'boxgrinder/validators/config-validator'
require 'rake/tasklib'

module BoxGrinder
  class Validator < Rake::TaskLib

    def initialize( config, options = {} )
      @config         = config
      @log            = options[:log] || Logger.new(STDOUT)

      define_tasks
    end

    def define_tasks

      desc "Validate appliance files definitions"
      task "validate:definitions" do
        validate_definitions
      end

      desc "Validate configuration"
      task "validate:config" do
        validate_configuration
      end

      desc "Validate everything"
      task "validate:all" => [ "validate:definitions", "validate:config" ]
    end

    def validate_definitions
      @log.debug "Validating appliance definitions..."

      begin
        raise ValidationError, "Appliance directory '#{@config.dir.appliances}' doesn't exists, please check your Rakefile" if @config.dir.appliances.nil? or !File.exists?(File.dirname( @config.dir.appliances )) or !File.directory?(File.dirname( @config.dir.appliances ))

        appliances = Dir[ "#{@config.dir.appliances}/*/*.appl" ]

        appliances.each do |appliance_def|
          ApplianceValidator.new( @config.dir.appliances, appliance_def ).validate
        end

        if appliances.size == 0
          @log.debug "No appliance definitions found in '#{@config.dir.appliances}' directory"
        else
          @log.debug "All #{appliances.size} appliances definitions are valid"
        end
      rescue ApplianceValidationError => appliance_validation_error
        raise "Error while validating appliance definition: #{appliance_validation_error}"
      rescue ValidationError => validation_error
        raise "Error while validating appliance definitions: #{validation_error}"
      rescue => exception
        raise "Something went wrong: #{exception}"
      end
    end

    def validate_configuration
      @log.debug "Validating configuration..."
      begin
        ConfigValidator.new( @config, :log => @log).validate
      rescue ValidationError => validation_error
        raise "Error while validating configuration: #{validation_error}"
      rescue => exception
        raise "Something went wrong: #{exception}"
      end

      @log.debug "Configuration is valid"
    end
  end
end
