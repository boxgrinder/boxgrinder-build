#
# List of OS Specific data
#
# Copyright 2006-2008  Red Hat, Inc.
# Jeremy Katz <katzj@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free  Software Foundation; either version 2 of the License, or
# (at your option)  any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301 USA.


"""
Default values for OS_TYPES keys. Can be overwritten at os_type or
variant level
"""
DEFAULTS = { \
    "acpi": True,
    "apic": True,
    "clock": "utc",
    "continue": False,
    "distro": None,
    "label": None,
    "pv_cdrom_install": False,
    "devices" : {
     #  "devname" : { "attribute" : [( ["applicable", "hv-type", list"],
     #                               "recommended value for hv-types" ),]},
        "input"   : { "type" : [ (["all"], "mouse") ],
                      "bus"  : [ (["all"], "ps2") ] },
        "disk"    : { "bus"  : [ (["all"], None) ] },
        "net"     : { "model": [ (["all"], None) ] },
    }
}

def sort_helper(tosort):
    """Helps properly sorting os dictionary entires"""
    key_mappings = {}
    keys = []
    retlist = []

    for key in tosort.keys():
        if tosort[key].get("skip"):
            continue

        sortby = tosort[key].get("sortby")
        if not sortby:
            sortby = key
        key_mappings[sortby] = key
        keys.append(sortby)

    keys.sort()
    for key in keys:
        retlist.append(key_mappings[key])

    return retlist

# NOTE: keep variant keys using only lowercase so we can do case
#       insensitive checks on user passed input
OS_TYPES = {\
"linux": { \
    "label": "Linux",
    "variants": { \
        "rhel2.1": { "label": "Red Hat Enterprise Linux 2.1",
                     "distro": "rhel" },
        "rhel3": { "label": "Red Hat Enterprise Linux 3",
                   "distro": "rhel" },
        "rhel4": { "label": "Red Hat Enterprise Linux 4",
                   "distro": "rhel" },
        "rhel5": { "label": "Red Hat Enterprise Linux 5",
                   "distro": "rhel" },
        "fedora5": { "sortby": "fedora05",
                     "label": "Fedora Core 5", "distro": "fedora" },
        "fedora6": { "sortby": "fedora06",
                     "label": "Fedora Core 6", "distro": "fedora" },
        "fedora7": { "sortby": "fedora07",
                     "label": "Fedora 7", "distro": "fedora" },
        "fedora8": { "sortby": "fedora08",
                     "label": "Fedora 8", "distro": "fedora" },
        "fedora9": { "sortby":  "fedora09",
                     "label": "Fedora 9", "distro": "fedora",
                      "devices" : {
                        # Apparently F9 has selinux errors when installing
                        # with virtio:
                        # https://bugzilla.redhat.com/show_bug.cgi?id=470386
                        #"disk" : { "bus"   : [ (["kvm"], "virtio") ] },
                        "net"  : { "model" : [ (["kvm"], "virtio") ] }
                      }},
        "fedora10": { "label": "Fedora 10", "distro": "fedora",
                      "devices" : {
                        "disk" : { "bus"   : [ (["kvm"], "virtio") ] },
                        "net"  : { "model" : [ (["kvm"], "virtio") ] }
                      }},
        "sles10": { "label": "Suse Linux Enterprise Server",
                    "distro": "suse" },
        "debianetch": { "label": "Debian Etch", "distro": "debian" },
        "debianlenny": { "label": "Debian Lenny", "distro": "debian",
                      "devices" : {
                        "disk" : { "bus"   : [ (["kvm"], "virtio") ] },
                        "net"  : { "model" : [ (["kvm"], "virtio") ] }
                      }},
        "ubuntuhardy": { "label": "Ubuntu Hardy", "distro": "ubuntu",
                         "devices" : {
                            "net"  : { "model" : [ (["kvm"], "virtio") ] }
                         }},
        "generic24": { "label": "Generic 2.4.x kernel" },
        "generic26": { "label": "Generic 2.6.x kernel" },
        "virtio26": { "sortby": "genericvirtio26",
                      "label": "Generic 2.6.25 or later kernel with virtio",
                      "devices" : {
                        "disk" : { "bus"   : [ (["kvm"], "virtio") ] },
                        "net"  : { "model" : [ (["kvm"], "virtio") ] }
                    }},

    },
},

"windows": { \
    "label": "Windows",
    "clock": "localtime",
    "continue": True,
    "devices" : {
        "input" : { "type" : [ (["all"], "tablet") ],
                    "bus"  : [ (["all"], "usb"), ] },
    },
    "variants": { \
        "winxp":{ "label": "Microsoft Windows XP (x86)",
                  "acpi": False, "apic": False },
        "winxp64":{ "label": "Microsoft Windows XP (x86_64)" },
        "win2k": { "label": "Microsoft Windows 2000",
                   "acpi": False, "apic": False },
        "win2k3": { "label": "Microsoft Windows 2003" },
        "win2k8": { "label": "Microsoft Windows 2008" },
        "vista": { "label": "Microsoft Windows Vista" },
    },
},

"solaris": {
    "label": "Solaris",
    "clock": "localtime",
    "pv_cdrom_install": True,
    "variants": {
        "solaris9": { "label": "Sun Solaris 9", },
        "solaris10": { "label": "Sun Solaris 10",
                       "devices" : { "input" : {
                         "type" : [ (["all"], "tablet") ],
                         "bus"  : [ (["all"], "usb"), ]
                         } },
                       },
        "opensolaris": { "label": "Sun OpenSolaris",
                       "devices" : { "input" : {
                           "type" : [ (["all"], "tablet") ],
                           "bus"  : [ (["all"], "usb"), ]
                         } },
                       },
    },
},

"unix": {
    "label": "UNIX",
    "variants": { \
        "freebsd6": { "label": "Free BSD 6.x" ,
                      # http://www.nabble.com/Re%3A-Qemu%3A-bridging-on-FreeBSD-7.0-STABLE-p15919603.html
                      "devices" : {
                        "net" : { "model" : [ (["all"], "ne2k_pci") ] }
                      }},
        "freebsd7": { "label": "Free BSD 7.x" ,
                      "devices" : {
                        "net" : { "model" : [ (["all"], "ne2k_pci") ] }
                      }},
        "openbsd4": { "label": "Open BSD 4.x" ,
                      # http://calamari.reverse-dns.net:980/cgi-bin/moin.cgi/OpenbsdOnQemu
                      # https://www.redhat.com/archives/et-mgmt-tools/2008-June/msg00018.html
                      "devices" : {
                        "net"  : { "model" : [ (["all"], "pcnet") ] }
                    }},
    },
},

"other": { \
    "label": "Other",
    "variants": { \
        "msdos": { "label": "MS-DOS", "acpi": False, "apic": False },
        "netware4": { "label": "Novell Netware 4" },
        "netware5": { "label": "Novell Netware 5" },
        "netware6": { "label": "Novell Netware 6" },
        "generic": { "label": "Generic" },
    },
},}

# Back compatibility entries
solaris_compat = OS_TYPES["unix"]["variants"]

solaris_compat["solaris9"] = OS_TYPES["solaris"]["variants"]["solaris9"].copy()
solaris_compat["solaris9"]["skip"] = True

solaris_compat["solaris10"] = OS_TYPES["solaris"]["variants"]["solaris10"].copy()
solaris_compat["solaris10"]["skip"] = True
