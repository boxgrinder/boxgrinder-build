require 'boxgrinder-build/plugins/delivery/base/base-delivery-plugin'

module BoxGrinder
  class LocalPlugin < BaseDeliveryPlugin
    def info
      {
              :name       => :local,
              :type       => [:local],
              :full_name  => "Local file system"
      }
    end

    def after_init
      set_default_config_value('overwrite', true)
      set_default_config_value('package', true)
    end

    def execute(deliverables, type = :local)      
      validate_plugin_config( [ 'path' ], 'http://community.jboss.org/docs/DOC-15216' )

      files = []

      if @plugin_config['package']
        files <<  PackageHelper.new(@config, @appliance_config, {:log => @log, :exec_helper => @exec_helper}).package(deliverables)
      else
        files << deliverables[:disk]

        [:metadata, :other].each do |deliverable_type|
          deliverables[deliverable_type].each_value do |file|
            files << file
          end
        end
      end

      if @plugin_config['overwrite'] or !already_delivered?(files)
        FileUtils.mkdir_p @plugin_config['path']

        @log.debug "Copying files to destination..."

        files.each do |file|
          @log.debug "Copying #{file}..."
          FileUtils.cp(file, @plugin_config['path'])
        end
        @log.info "Appliance delivered to #{@plugin_config['path']}."
      else
        @log.info "Appliance already delivered to #{@plugin_config['path']}."
      end
    end

    def already_delivered?(files)
      files.each do |file|
        return false unless File.exists?("#{@plugin_config['path']}/#{File.basename(file)}")
      end
      true
    end
  end
end