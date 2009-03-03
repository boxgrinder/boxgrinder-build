require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'

module JBossCloud
  class ParameterValidator
    def initialize
    end

    def validate
      raise ValidationError, "'#{ENV['ARCH']}' is not a valid build architecture. Available architectures: #{Config.supported_arches.join(", ")}." if (!ENV['ARCH'].nil? and !Config.supported_arches.include?( ENV['ARCH']))
      raise ValidationError, "'#{ENV['DISK_SIZE']}' is not a valid disk size. Please enter valid size in MB." if !ENV['DISK_SIZE'].nil? && (ENV['DISK_SIZE'].to_i == 0 || ENV['DISK_SIZE'].to_i % 1024 > 0)
      
    end

    protected

  end
end
