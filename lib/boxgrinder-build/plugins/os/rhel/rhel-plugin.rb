require 'boxgrinder-build/plugins/os/base-operating-system-plugin'

module BoxGrinder
  class RHELPlugin < BaseOperatingSystemPlugin
    def os
      {
              :name       => :rhel,
              :full_name  => "Red Hat Enterprise Linux",
              :versions   => ["5"]
      }
    end

    def build( config, image_config )

    end
  end
end