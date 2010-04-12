require 'boxgrinder-build/managers/operating-system-plugin-manager'
require 'boxgrinder-build/managers/platform-plugin-manager'

module BoxGrinder
  class PluginHelper
    def initialize( options = {} )
      @log = options[:log] || Logger.new(STDOUT)
    end

    def load_plugins
      Dir["#{File.dirname( __FILE__ )}/../plugins/**/*.rb"].each {|file| require file }

      load_os_plugins
      load_platform_plugins

      self
    end

    def load_os_plugins
      @log.debug "Loading operating system plugins..."

      @os_plugins = OperatingSystemPluginManager.instance.initialize_plugins.plugins

      @log.debug "We have #{@os_plugins.size} operating system plugin(s) registered"

      @os_plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]} #{plugin.info[:versions].join(', ')}."
      end

      @log.debug "Plugins loaded."
    end

    def load_platform_plugins
      @log.debug "Loading platform plugins..."

      @platform_plugins = PlatformPluginManager.instance.initialize_plugins.plugins

      @log.debug "We have #{@platform_plugins.size} platform plugin(s) registered"

      @platform_plugins.each_value do |plugin|
        @log.debug "- plugin for #{plugin.info[:full_name]}."
      end

      @log.debug "Plugins loaded."
    end

    attr_reader :os_plugins
    attr_reader :platform_plugins
  end
end