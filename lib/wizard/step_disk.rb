require 'jboss-cloud/wizard/step'

module JBossCloudWizard
  class StepDisk < Step
    def initialize(config)
      @config = config
    end

    def start
      ask_for_disk

      @config
    end

    def default_disk_size(appliance)
      if appliance == "meta-appliance"
        disk_size = 10
      else
        disk_size = 2
      end

      disk_size
    end

    def ask_for_disk

      disk_size = default_disk_size(@config.name)

      print "\n#{banner} How big should be the disk (in GB)? [#{disk_size}] "

      disk_size = gets.chomp

      ask_for_disk unless valid_disk_size?( disk_size )
    end

    def valid_disk_size?( disk_size )
      if (disk_size.length == 0)
        disk_size = default_disk_size(@config.name)
      end

      if disk_size.to_i == 0
        puts "\n    Sorry, '#{disk_size}' is not a valid value" unless disk_size.length == 0
        return false
      end

      min_disk_size = default_disk_size(@config.name)

      if (disk_size.to_i < min_disk_size)
        puts "\n    Sorry, #{disk_size}GB is not enough for #{@config.name}, please give >= #{min_disk_size}GB"
        return false
      end

      puts "\n    You have selected #{disk_size}GB disk"

      @config.disk_size = disk_size
      return true
    end

  end
end