#
# Copyright 2006  Red Hat, Inc.
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
#

#
# Internal utility functions. These do NOT form part of the API and must
# not be used by clients.
#

import stat
import os
import re
import commands

import libvirt

from virtinst import util

def is_vdisk(path):
    if not os.path.exists("/usr/sbin/vdiskadm"):
        return False
    if not os.path.exists(path):
        return True
    if os.path.isdir(path) and \
       os.path.exists(path + "/vdisk.xml"):
        return True
    return False

def stat_disk(path):
    """Returns the tuple (isreg, size)."""
    if not os.path.exists(path):
        return True, 0

    if is_vdisk(path):
        size = int(commands.getoutput(
            "vdiskadm prop-get -p max-size " + path))
        return True, size

    mode = os.stat(path)[stat.ST_MODE]

    # os.path.getsize('/dev/..') can be zero on some platforms
    if stat.S_ISBLK(mode):
        fd = os.open(path, os.O_RDONLY)
        # os.SEEK_END is not present on all systems
        size = os.lseek(fd, 0, 2)
        os.close(fd)
        return False, size
    elif stat.S_ISREG(mode):
        return True, os.path.getsize(path)

    return True, 0

def blkdev_size(path):
    """Return the size of the block device.  We can't use os.stat() as
    that returns zero on many platforms."""
    fd = os.open(path, os.O_RDONLY)
    # os.SEEK_END is not present on all systems
    size = os.lseek(fd, 0, 2)
    os.close(fd)
    return size

def sanitize_arch(arch):
    """Ensure passed architecture string is the format we expect it.
       Returns the sanitized result"""
    if not arch:
        return arch
    tmparch = arch.lower().strip()
    if re.match(r'i[3-9]86', tmparch):
        return "i686"
    elif tmparch == "amd64":
        return "x86_64"
    return arch

def vm_uuid_collision(conn, uuid):
    """
    Check if passed UUID string is in use by another guest of the connection
    Returns true/false
    """
    check = False
    if uuid is not None:
        try:
            if conn.lookupByUUIDString(uuid) is not None:
                check = True
        except libvirt.libvirtError:
            pass
    return check

#
# These functions accidentally ended up in the API under virtinst.util
#
default_route = util.default_route
default_bridge = util.default_bridge
default_network = util.default_network
default_connection = util.default_connection
get_cpu_flags = util.get_cpu_flags
is_pae_capable = util.is_pae_capable
is_blktap_capable = util.is_blktap_capable
get_default_arch = util.get_default_arch
randomMAC = util.randomMAC
randomUUID = util.randomUUID
uuidToString = util.uuidToString
uuidFromString = util.uuidFromString
get_host_network_devices = util.get_host_network_devices
get_max_vcpus = util.get_max_vcpus
get_phy_cpus = util.get_phy_cpus
xml_escape = util.xml_escape
compareMAC = util.compareMAC
default_keymap = util.default_keymap
pygrub_path = util.pygrub_path
uri_split = util.uri_split
is_uri_remote = util.is_uri_remote
get_uri_hostname = util.get_uri_hostname
get_uri_transport = util.get_uri_transport
get_uri_driver = util.get_uri_driver
is_storage_capable = util.is_storage_capable
get_xml_path = util.get_xml_path
lookup_pool_by_path = util.lookup_pool_by_path
