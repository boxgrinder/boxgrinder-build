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

import gettext

gettext_dir = "::LOCALEDIR::"
gettext_app = "virtinst"

gettext.bindtextdomain(gettext_app, gettext_dir)

def _virtinst(msg):
    return gettext.dgettext(gettext_app, msg)

import util
from Guest import Guest, VirtualNetworkInterface, XenGuest, \
                  XenNetworkInterface, VirtualGraphics, VirtualAudio
from VirtualDisk import VirtualDisk, XenDisk
from FullVirtGuest import FullVirtGuest
from ParaVirtGuest import ParaVirtGuest
from DistroManager import DistroInstaller, PXEInstaller
from LiveCDInstaller import LiveCDInstaller
from ImageManager import ImageInstaller
from CloneManager import CloneDesign
from User import User
