module JBossCloud
  # here are global variables
  SUPPORTED_ARCHES = [ "i386", "x86_64" ]
  SUPPORTED_OSES = {
    "fedora" => [ "10", "rawhide" ]
  }
  
  STABLE_RELEASES = {
    "fedora" => "10",
    "rhel" => "5"
  }
  
  APPLIANCE_DEFAULTS = {
    "os_name" => "fedora",
    "os_version" => STABLE_RELEASES['fedora'],
    "disk_size" => 2,
    "mem_size" => 1024,
    "network_name" => "NAT",
    "vcpu" => 1,
    "arch" => (-1.size) == 8 ? "x86_64" : "i386"
  } 
  
  # you can use #ARCH# variable to specify build arch
  REPOS = {
      "fedora" => { 
        "10" => { 
          "base" => {
            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-10&arch=#ARCH#"
        },
          "updates" => {
            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f10&arch=#ARCH#"
        }
      },
        "rawhide" => {
          "base" => {
            "mirrorlist" => "http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=#ARCH#"
        }
      }
    }
  }
end