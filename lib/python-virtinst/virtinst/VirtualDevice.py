#
# Base class for all VM devices
#
# Copyright 2008  Red Hat, Inc.
# Cole Robinson <crobinso@redhat.com>
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

import libvirt

import CapabilitiesParser
import _util
from virtinst import _virtinst as _

class VirtualDevice(object):
    """
    Base class for all domain xml device objects.
    """

    def __init__(self, conn=None):
        """
        Initialize device state

        @param conn: libvirt connection to validate device against
        @type conn: virConnect
        """

        if conn:
            if not isinstance(conn, libvirt.virConnect):
                raise ValueError, _("'conn' must be a virConnect instance")
        self._conn = conn

        self.__remote = None
        if self.conn:
            self.__remote = _util.is_uri_remote(self.conn.getURI())

        self._caps = None
        if self.conn:
            self._caps = CapabilitiesParser.parse(self.conn.getCapabilities())

    def get_conn(self):
        return self._conn
    def set_conn(self, val):
        if not isinstance(val, libvirt.virConnect):
            raise ValueError(_("'conn' must be a virConnect instance."))
        self._conn = val
    conn = property(get_conn, set_conn)

    def _is_remote(self):
        return self.__remote

    def _check_bool(self, val, name):
        if val not in [True, False]:
            raise ValueError, _("'%s' must be True or False" % name)

    def _check_str(self, val, name):
        if type(val) is not str:
            raise ValueError, _("'%s' must be a string, not '%s'." %
                                (name, type(val)))

    def get_xml_config(self):
        """
        Construct and return device xml

        @return: device xml representation as a string
        @rtype: str
        """
        raise NotImplementedError()
