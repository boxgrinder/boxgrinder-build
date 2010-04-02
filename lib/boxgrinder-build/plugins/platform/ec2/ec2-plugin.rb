require 'boxgrinder-build/plugins/platform/base-platform-plugin'

module BoxGrinder
  class EC2Plugin < BasePlatformPlugin
    def info
      {
              :name       => :ec2,
              :full_name  => "Amazon Elastic Compute Cloud"
      }
    end
  end
end