require 'rake/tasklib'
require 'yaml'

require 'jboss-cloud/appliance-source.rb'
require 'jboss-cloud/appliance-spec.rb'
require 'jboss-cloud/appliance-rpm.rb'
require 'jboss-cloud/appliance-kickstart.rb'
require 'jboss-cloud/appliance-image.rb'

module JBossCloud

  class MultiAppliance < Rake::TaskLib

    def initialize( config, multi_appliance_def )
      @multi_appliance_def  = multi_appliance_def
      @config               = config
      @config.appliances    = YAML.load_file( @multi_appliance_def )['appliances']

      define
    end

    def define
      define_precursors
    end

    def define_precursors
      #JBossCloud::ApplianceSource.new( @config, File.dirname( @multi_appliance_def ) )
      #JBossCloud::ApplianceSpec.new( @config, @multi_appliance_def )
      #JBossCloud::ApplianceRPM.new( @topdir, "#{@build_dir}/appliances/#{simple_name}/#{simple_name}.spec", @version, @release )

      JBossCloud::ApplianceKickstart.new( @config, @config.appliances )
      JBossCloud::ApplianceImage.new( @config, @config.appliances )
    end

  end
end
