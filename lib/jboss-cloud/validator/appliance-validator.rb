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
require 'yaml'

module JBossCloud
  class ApplianceValidator
    def initialize( dir_appliances, appliance_def )
      raise ValidationError, "Appliance directory doesn't exists" if dir_appliances.nil? or ( !File.exists?(File.dirname( dir_appliances )) && !File.directory?(File.dirname( dir_appliances )) )
      
      @dir_appliances = dir_appliances
      
      #check if appliance_def is nil
      raise ValidationError, "Appliance definition file must be specified" if appliance_def.nil?
      
      @appliance_name = File.basename( appliance_def, '.appl' )
      
      # check if file exists
      raise ValidationError, "Appliance definition file for '#{@appliance_name}' doesn't exists" unless File.exists?( appliance_def )
      
      @appliance_def = appliance_def
    end
    
    def validate
      @definition = YAML.load_file( @appliance_def )
      # check for summary
      raise ValidationError, "Appliance definition file for '#{@appliance_name}' should have summary" if @definition['summary'].nil? or @definition['summary'].length == 0
      # check if all dependent appliances exists
      appliances, valid = get_appliances(@appliance_name)
      raise ValidationError, "Could not find all dependent appliances for multiappliance '#{@appliance_name}'" unless valid
      # check appliance count
      raise ValidationError, "Invalid appliance count for appliance '#{@appliance_name}'" unless appliances.size >= 1
      # check if puppet configuration file exists
      puppet_file = "#{File.dirname( @appliance_def )}/#{@appliance_name}.pp"      
      raise ValidationError, "Puppet configuration file '#{puppet_file}' doesn't exists for appliance '#{@appliance_name}'" unless File.exists?( puppet_file )
    end
    
    protected
    
    def get_config
      validate( build_config )
    end
    
    def get_appliances( appliance_name )
      appliances = Array.new
      valid = true
      
      appliance_def = "#{@dir_appliances}/#{appliance_name}/#{appliance_name}.appl"
      
      unless  File.exists?( appliance_def )
        puts "Appliance configuration file for '#{appliance_name}' doesn't exists, please check your config files."
        return false
      end
      
      appliances_read = YAML.load_file( appliance_def )['appliances']
      
      appliances_read.each do |appl|
        appls, v = get_appliances( appl )
        
        appliances += appls if v
        valid = false unless v
      end unless appliances_read.nil? or appliances_read.empty?
      
      appliances.push( appliance_name )
      
      [ appliances, valid ]
    end
    
  end
end
