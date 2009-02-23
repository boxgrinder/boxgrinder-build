require 'rake/tasklib'

require 'jboss-cloud/appliance-source.rb'
require 'jboss-cloud/appliance-spec.rb'
require 'jboss-cloud/appliance-rpm.rb'
require 'jboss-cloud/appliance-kickstart.rb'
require 'jboss-cloud/appliance-image.rb'

module JBossCloud

  class Appliance < Rake::TaskLib

    def initialize( config, appliance_def )
      @appliance_def    = appliance_def
      @config           = config

      define
    end

    def define
      define_precursors
    end

    def define_precursors
      JBossCloud::ApplianceSource.new( @config, File.dirname( @appliance_def ) )
      JBossCloud::ApplianceSpec.new( @config )
      JBossCloud::ApplianceRPM.new( @config )
      JBossCloud::ApplianceKickstart.new( @config )
      JBossCloud::ApplianceImage.new( @config, @config.name )
    end
  end
end
