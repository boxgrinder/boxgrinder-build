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

require 'optparse' 
require 'ostruct'
require 'yaml'
require 'jboss-cloud-wizard/wizard'

module JBossCloudWizard
  class App

    def initialize( config = Hash.new )
      @arguments = ARGV
      @stdin     = STDIN

      @options                  = OpenStruct.new
      @options.verbose          = false
      @options.name             = config[:name]           || "JBoss Appliance Support"
      @options.version          = config[:version]        || "1.0.0.Beta6"
      @options.release          = config[:release]        || "1"
      @options.dir_appliances   = config[:dir_appliances] || "appliances"

      validate
      #todo initialize all paths
    end

    def validate
      if @options.name == nil or @options.version == nil
        puts "You should specify at least name and version for your project, aborting."
        abort
      end

      if !File.exists?(@options.dir_appliances) && !File.directory?(@options.dir_appliances)
        puts "Appliance directory #{@options.dir_appliances} doesn't exists, aborting."
        abort
      end

      if Dir[ "#{@options.dir_appliances}/*/*.appl" ].size == 0
        puts "There are no appliances in '#{@options.dir_appliances}' directory, please check one more time path, aborting."
        abort
      end
    end

    def run
      if !parsed_options?
        puts "Invalid options"
        exit(0)
      end
      
      JBossCloudWizard::Wizard.new(@options).init.start
    end

    protected

    def output_version
      puts "Appliance builder wizard for #{@options.name}, version #{@options.release.nil? ? @options.version : @options.version + "-" + @options.release}"
    end

    # Performs post-parse processing on options
    def process_options
      # @options.verbose = false if @options.quiet
    end

    def parsed_options?
      # Specify options
      opts = OptionParser.new
      opts.on('-v', '--version')    { output_version ; exit 0 }
      opts.on('-V', '--verbose')    { @options.verbose = true }

      opts.parse!(@arguments) rescue return false

      process_options
      true
    end
  end
end
