require 'boxgrinder-build/managers/platform-plugin-manager'
require 'boxgrinder-build/plugins/base-plugin'

module BoxGrinder
  class BasePlatformPlugin < BasePlugin
    def self.inherited(klass)
      PlatformPluginManager.instance << klass
    end

    def convert
      raise "Not implemented!"
    end
  end
end