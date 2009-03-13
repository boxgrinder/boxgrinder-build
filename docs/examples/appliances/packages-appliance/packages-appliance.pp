# Modules used by the appliance
import "appliance_base"
import "banners"
import "firewall"
import "ssh"

# Information about our appliance
$appliance_name = "<%= appliance_summary %>"
$appliance_version = "<%= appliance_version %>"

# Configuration
appliance_base::setup{$appliance_name:}
appliance_base::enable_updates{$appliance_name:}
banners::all{$appliance_name:}
firewall::setup{$appliance_name: status=>"disabled"}
ssh::setup{$appliance_name:}
