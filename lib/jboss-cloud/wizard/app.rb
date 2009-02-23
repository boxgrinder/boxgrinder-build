require 'optparse' 
require 'ostruct'
require 'jboss-cloud/wizard/wizard'

module JBossCloudWizard
  class App
    VERSION = '1.0.0.Beta2'

    def initialize(arguments, stdin)
      @arguments = arguments
      @stdin = stdin

      @options = OpenStruct.new
      @options.verbose = false
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
      puts "JBoss Cloud appliance builder wizard, version #{VERSION}"
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
