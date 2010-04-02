require 'boxgrinder-build/managers/operating-system-plugin-manager'

module BoxGrinder
  class BaseOperatingSystemPlugin
    def self.inherited(klass)
     OperatingSystemPluginManager.instance << klass
    end

    def os
      {}
    end

    def build
      raise "Not implemented!"
    end
  end
end