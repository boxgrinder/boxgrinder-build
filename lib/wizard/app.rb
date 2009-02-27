require 'optparse' 
require 'ostruct'
require 'wizard/wizard'

module JBossCloudWizard
  class App

    DEFAULT_CONFIG = {
      :dir_appliances     => 'appliances'
    }

    def initialize( config )
      @arguments = ARGV
      @stdin     = STDIN

      @options                  = OpenStruct.new
      @options.verbose          = false
      @options.name             = config[:name]
      @options.version          = config[:version]
      @options.release          = config[:release]
      @options.dir_appliances   = config[:dir_appliances] || DEFAULT_CONFIG[:dir_appliances]

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
