#
# An installer class for LiveCD images
#
# Copyright 2007  Red Hat, Inc.
# Mark McLoughlin <markmc@redhat.com>
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

import Guest
from VirtualDisk import VirtualDisk
import CapabilitiesParser
from virtinst import _virtinst as _

class LiveCDInstallerException(Exception):
    def __init__(self, msg):
        Exception.__init__(self, msg)

class LiveCDInstaller(Guest.Installer):
    def __init__(self, type = "xen", location = None, os_type = None,
                 conn = None):
        Guest.Installer.__init__(self, type=type, location=location,
                                 os_type=os_type, conn=conn)

    def prepare(self, guest, meter, distro = None):
        self.cleanup()

        capabilities = CapabilitiesParser.parse(guest.conn.getCapabilities())

        found = False
        for guest_caps in capabilities.guests:
            if guest_caps.os_type == "hvm":
                found = True
                break

        if not found:
            raise LiveCDInstallerException(_("Connection does not support HVM virtualisation, cannot boot live CD"))

        path = None
        vol_tuple = None
        if type(self.location) is tuple:
            vol_tuple = self.location
        elif self.location:
            path = self.location
        elif not self.cdrom:
            raise LiveCDInstallerException(_("CDROM media must be specified "
                                             "for the live CD installer."))

        if path or vol_tuple:
            disk = VirtualDisk(path=path, conn=guest.conn, volName=vol_tuple,
                               device = VirtualDisk.DEVICE_CDROM,
                               readOnly = True)
            guest._install_disks.insert(0, disk)

    def _get_osblob(self, install, hvm, arch=None, loader=None, conn=None):
        if install:
            # XXX: This seems wrong? If install is True, maybe we should
            # error and say that isn't a valid value for LiveCD?
            return None

        return self._get_osblob_helper(isinstall=install, ishvm=hvm,
                                       arch=arch, loader=loader, conn=conn,
                                       kernel=None, bootdev="cdrom")

    def post_install_check(self, guest):
        return True
