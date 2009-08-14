module JBossCloud
  class ReleaseHelper
    def initialize( config, options = {} )
      @config = config

      @log          = options[:log]         || LOG
      @exec_helper  = options[:exec_helper] || EXEC_HELPER

      define_tasks
    end

    def define_tasks
      task "appliance:upload:release" do
        prepare_release
      end
    end

    def prepare_release
      if @config.release.appliances.nil?
        @log.error "No appliances selected for a release, see release/appliances section in your config file."
        return
      end

      build_required_images
    end

    def build_required_images
      @log.info "Building and packaging required appliances..."

      release_thread_group = ThreadGroup.new

      for appliance in @config.release.appliances
        Rake::Task[ "appliance:#{appliance}:package" ].invoke
        release_thread_group.add Thread.new { Rake::Task[ "appliance:#{appliance}:upload" ].invoke }
      end

      for thread in release_thread_group.list
        thread.join
      end

      @log.info "Required appliance are build."
    end
  end
end