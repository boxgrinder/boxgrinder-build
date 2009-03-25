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

require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'
require 'jboss-cloud/validator/appliance-validator'
require 'jboss-cloud/validator/config-validator'
require 'rake/tasklib'

module JBossCloud
  class Validator < Rake::TaskLib
    
    def initialize( config )
      @config = config
      
      define
    end
    
    def define     
      
      desc "Validate appliance files definitions"
      task "validate:definitions" do     
        
        puts "Validating appliances definitions..." if JBossCloud.validation_task?
        
        begin         
          raise ValidationError, "Appliance directory '#{@config.dir.appliances}' doesn't exists, please check your Rakefile" if @config.dir.appliances.nil? or !File.exists?(File.dirname( @config.dir.appliances )) or !File.directory?(File.dirname( @config.dir.appliances ))
          
          appliances = Dir[ "#{@config.dir.appliances}/*/*.appl" ]
          
          appliances.each do |appliance_def|
            ApplianceValidator.new( @config.dir.appliances, appliance_def ).validate
          end
          
          if appliances.size == 0
            puts "No appliance definitions found in '#{@config.dir.appliances}' directory" if JBossCloud.validation_task?
          else
            puts "All #{appliances.size} appliances definitions are valid" if JBossCloud.validation_task?
          end  
        rescue ApplianceValidationError => appliance_validation_error
          raise "Error while validating appliance definition: #{appliance_validation_error}"
        rescue ValidationError => validation_error
          raise "Error while validating appliance definitions: #{validation_error}"
        rescue => exception
          raise "Something went wrong: #{exception}"
        end
        
      end
      
      desc "Validate configuration"
      task "validate:config" do
        puts "Validating configuration..." if JBossCloud.validation_task?
        begin
          ConfigValidator.new.validate( @config )
        rescue ValidationError => validation_error
          raise "Error while validating configuration: #{validation_error}"
        rescue => exception
          raise "Something went wrong: #{exception}"
        end
        
        puts "Configuration is valid" if JBossCloud.validation_task?
      end
      
      desc "Validate everything"
      task "validate:all" => [ "validate:definitions", "validate:config" ]
    end
    
  end
end
