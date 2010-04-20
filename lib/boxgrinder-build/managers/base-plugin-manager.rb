require 'singleton'
module BoxGrinder
  class BasePluginManager
    include Singleton

    def initialize
      @plugin_classes = []
      @plugins        = {}
    end

    def <<(plugin_class)
      @plugin_classes << plugin_class
    end

    def initialize_plugins( options = {} )
      log = options[:log] || Logger.new(STDOUT)

      @plugin_classes.each do |plugin_class|
        begin
          plugin = plugin_class.new
        rescue => e
          raise "Error while initializing #{plugin_class} plugin.", e
        end

        next unless plugin.respond_to?(:info)

        plugin.instance_variable_set( :@log, log )

        if @plugins[plugin.info[:name]].nil?
          @plugins[plugin.info[:name]] = plugin
        else
          raise "We already have registered plugin for #{plugin.info[:name]} OS."
        end
      end
      self
    end

    attr_reader :plugins

  end
end
