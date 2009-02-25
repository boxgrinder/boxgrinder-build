require 'optparse' 
require 'ostruct'
require 'wizard/wizard'

module JBossCloudWizard
  class App

    def initialize(name, version, release, arguments, stdin)
      @name      = name
      @version   = version
      @release   = release
      @arguments = arguments
      @stdin     = stdin

      @options   = OpenStruct.new
      @options.verbose  = false
      @options.name     = @name
      @options.version  = @version
      @options.release  = @release
      #todo initialize all paths
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
      puts "Appliance builder wizard for #{@name}, version #{@release.nil? ? @version : @version + "-" + @release}"
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
