require 'rake/tasklib'

require 'jboss-cloud/appliance-source.rb'
require 'jboss-cloud/appliance-spec.rb'
require 'jboss-cloud/appliance-rpm.rb'
require 'jboss-cloud/appliance-kickstart.rb'
require 'jboss-cloud/appliance-image.rb'

module JBossCloud
  
  class Appliance < Rake::TaskLib
    
    def initialize( config, appliance_config, appliance_def )
      @config            = config
      @appliance_def     = appliance_def
      @appliance_config  = appliance_config
      
      define
    end
    
    def define
      define_precursors
    end
    
    def define_precursors
      JBossCloud::ApplianceSource.new( @config, @appliance_config )
      JBossCloud::ApplianceSpec.new( @config, @appliance_config )
      JBossCloud::ApplianceRPM.new( @config, @appliance_config )
      JBossCloud::ApplianceKickstart.new( @appliance_config )
      JBossCloud::ApplianceImage.new( @appliance_config )
    end
  end
end
