require 'jboss-cloud/wizard/step'

module JBossCloudWizard
  class StepAppliance < Step

    def initialize(appliances, arches)
      @appliances = appliances
      @arches = arches
    end

    def start
      ask_for_appliance
      ask_for_architecture

      config = JBossCloud::ApplianceConfig.new
      config.name = @appliance
      config.arch = @arch

      # default settings
      config.vcpu = 1
      
      # TODO: change this
      config.os_name = "fedora"
      config.os_version = 10

      config
    end

    def ask_for_architecture
      current_arch = (-1.size) == 8 ? "x86_64" : "i386"

      if current_arch == "i386"
        # puts "Current architecture is i386, you can build only 32bit appliances"
        @arch = "i386"
        return
      else

        list_architectures

        print "#{banner} Which architecture do you want to select? (1-#{@arches.size}) "

        arch = gets.chomp

        ask_for_architecture unless valid_architecture?(arch)
      end
      
    end

    def ask_for_appliance
      list_appliances

      print "#{banner} Which appliance do you want to build? (1-#{@appliances.size}) "

      appliance = gets.chomp

      ask_for_appliance unless valid_appliance?( appliance )
    end

    def list_architectures
      puts "\n#{banner} Available architectures:"

      i = 0

      puts
      @arches.each do |arch|
        puts "    #{i += 1}. " + arch
      end
      puts
    end

    def list_appliances
      puts "\n#{banner} Available appliances:"

      i = 0
      
      puts
      @appliances.each do |appliance|
        puts "    #{i += 1}. " + appliance
      end
      puts
    end

    def valid_appliance?(appliance)
      return false if appliance.to_i == 0 or appliance.length == 0

      appliance = appliance.to_i

      return false unless appliance >= 1 and appliance <= @appliances.size

      @appliance = @appliances[appliance - 1]
      puts "\n    You have selected #{@appliance}"
      
      return true
    end

    def valid_architecture?(arch)
      return false if arch.to_i == 0 or arch.length == 0

      arch = arch.to_i

      return false unless arch >= 1 and arch <= @arches.size

      @arch = @arches[arch - 1]
      puts "\n    You have selected #{@arch} architecture"

      return true
    end
  end
end
