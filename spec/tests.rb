RSPEC_BASE_LOCATION = File.dirname(__FILE__)

# images
#require 'images/raw-image-spec'
#require 'images/vmware-image-spec'
#require 'images/ec2-image-spec'

require 'plugins/os/base/rpm-based-os-plugin-spec'
require 'plugins/os/base/kickstart-spec'

require 'plugins/platform/ec2/ec2-plugin-spec'
require 'plugins/platform/vmware/vmware-plugin-spec'