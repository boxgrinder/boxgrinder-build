require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'

module JBossCloud
  class ApplianceConfigParameterValidator
    def validate
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_ARCH']}' is not a valid build architecture. Available architectures: #{Config.supported_arches.join(", ")}." if (!ENV['JBOSS_CLOUD_ARCH'].nil? and !Config.supported_arches.include?( ENV['JBOSS_CLOUD_ARCH']))
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_OS_NAME']}' is not a valid OS name. Please enter valid name." if !ENV['JBOSS_CLOUD_OS_NAME'].nil? && !Config.supported_oses.keys.include?( ENV['JBOSS_CLOUD_OS_NAME'] )
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_OS_VERSION']}' is not a valid OS version for. Please enter valid version." if !ENV['JBOSS_CLOUD_OS_VERSION'].nil? && !Config.supported_oses[@config.os_name].include?( ENV['JBOSS_CLOUD_OS_VERSION'] )
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_DISK_SIZE']}' is not a valid disk size. Please enter valid size in GB." if !ENV['JBOSS_CLOUD_DISK_SIZE'].nil? && ENV['JBOSS_CLOUD_DISK_SIZE'].to_i == 0
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_MEM_SIZE']}' is not a valid memory size. Please enter valid size in MB." if !ENV['JBOSS_CLOUD_MEM_SIZE'].nil? && ENV['JBOSS_CLOUD_MEM_SIZE'].to_i == 0
      raise ValidationError, "'#{ENV['JBOSS_CLOUD_VCPU']}' is not a valid virtual cpu amount. Please enter valid amount." if !ENV['JBOSS_CLOUD_VCPU'].nil? && ENV['JBOSS_CLOUD_VCPU'].to_i == 0
    end
  end
end
