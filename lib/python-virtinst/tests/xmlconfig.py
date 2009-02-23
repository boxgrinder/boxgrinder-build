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

import unittest
import os
import libvirt
import urlgrabber.progress as progress

import virtinst
import tests

def get_basic_paravirt_guest():
    conn = libvirt.open("test:///default")
    g = virtinst.ParaVirtGuest(connection=conn, type="xen")
    g.name = "TestGuest"
    g.memory = int(200)
    g.maxmemory = int(400)
    g.uuid = "12345678-1234-1234-1234-123456789012"
    g.boot = ["/boot/vmlinuz","/boot/initrd"]
    g.graphics = (True, "vnc", None, "ja")
    g.vcpus = 5
    return g

def get_basic_fullyvirt_guest():
    conn = libvirt.open("test:///default")
    g = virtinst.FullVirtGuest(connection=conn, type="xen",
                               emulator="/usr/lib/xen/bin/qemu-dm",
                               arch="i686")
    g.name = "TestGuest"
    g.memory = int(200)
    g.maxmemory = int(400)
    g.uuid = "12345678-1234-1234-1234-123456789012"
    g.cdrom = "/dev/loop0"
    g.set_os_type("other")
    g.set_os_variant("generic")
    g.graphics = (True, "sdl")
    g.features['pae'] = 0
    g.vcpus = 5
    return g

class TestXMLConfig(unittest.TestCase):

    def _compare(self, xenguest, filebase, install):
        filename = os.path.join("tests/xmlconfig-xml", filebase + ".xml")
        xenguest._prepare_install(progress.BaseMeter())
        try:
            actualXML = xenguest.get_config_xml(install=install)
            tests.diff_compare(actualXML, filename)

            # Should probably break this out into a separate function
            dom = xenguest.conn.defineXML(actualXML)
            dom.create()
        finally:
            xenguest.installer.cleanup()


    def testBootParavirtDiskFile(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE,size=5))
        self._compare(g, "boot-paravirt-disk-file", False)

    def testBootParavirtDiskBlock(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK))
        self._compare(g, "boot-paravirt-disk-block", False)

    def testBootParavirtDiskDrvPhy(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK, \
                                       driverName = virtinst.VirtualDisk.DRIVER_PHY))
        self._compare(g, "boot-paravirt-disk-drv-phy", False)

    def testBootParavirtDiskDrvFile(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_FILE,size=5))
        self._compare(g, "boot-paravirt-disk-drv-file", False)

    def testBootParavirtDiskDrvTap(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_TAP,size=5))
        self._compare(g, "boot-paravirt-disk-drv-tap", False)

    def testBootParavirtDiskDrvTapQCow(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_TAP, \
                                       driverType = virtinst.VirtualDisk.DRIVER_TAP_QCOW,size=5))
        self._compare(g, "boot-paravirt-disk-drv-tap-qcow", False)

    def testBootParavirtManyDisks(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test1.img", type=virtinst.VirtualDisk.TYPE_FILE,size=5))
        g.disks.append(virtinst.VirtualDisk("/tmp/test2.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_TAP, \
                                       driverType = virtinst.VirtualDisk.DRIVER_TAP_QCOW,size=5))
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK))
        self._compare(g, "boot-paravirt-many-disks", False)

    def testBootFullyvirtDiskFile(self):
        g = get_basic_fullyvirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE,size=5))
        self._compare(g, "boot-fullyvirt-disk-file", False)

    def testBootFullyvirtDiskBlock(self):
        g = get_basic_fullyvirt_guest()
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK))
        self._compare(g, "boot-fullyvirt-disk-block", False)




    def testInstallParavirtDiskFile(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE,size=5))
        self._compare(g, "install-paravirt-disk-file", True)

    def testInstallParavirtDiskBlock(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK))
        self._compare(g, "install-paravirt-disk-block", True)

    def testInstallParavirtDiskDrvPhy(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK, \
                                       driverName = virtinst.VirtualDisk.DRIVER_PHY))
        self._compare(g, "install-paravirt-disk-drv-phy", True)

    def testInstallParavirtDiskDrvFile(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_FILE,size=5))
        self._compare(g, "install-paravirt-disk-drv-file", True)

    def testInstallParavirtDiskDrvTap(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_TAP,size=5))
        self._compare(g, "install-paravirt-disk-drv-tap", True)

    def testInstallParavirtDiskDrvTapQCow(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_TAP, \
                                       driverType = virtinst.VirtualDisk.DRIVER_TAP_QCOW,size=5))
        self._compare(g, "install-paravirt-disk-drv-tap-qcow", True)

    def testInstallParavirtManyDisks(self):
        g = get_basic_paravirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test1.img", type=virtinst.VirtualDisk.TYPE_FILE,size=5))
        g.disks.append(virtinst.VirtualDisk("/tmp/test2.img", type=virtinst.VirtualDisk.TYPE_FILE, \
                                       driverName = virtinst.VirtualDisk.DRIVER_TAP, \
                                       driverType = virtinst.VirtualDisk.DRIVER_TAP_QCOW,size=5))
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK))
        self._compare(g, "install-paravirt-many-disks", True)

    def testInstallFullyvirtDiskFile(self):
        g = get_basic_fullyvirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/test.img", type=virtinst.VirtualDisk.TYPE_FILE,size=5))
        self._compare(g, "install-fullyvirt-disk-file", True)

    def testInstallFullyvirtDiskBlock(self):
        g = get_basic_fullyvirt_guest()
        g.disks.append(virtinst.VirtualDisk("/dev/loop0", type=virtinst.VirtualDisk.TYPE_BLOCK))
        self._compare(g, "install-fullyvirt-disk-block", True)

    def testInstallFVPXE(self):
        g = get_basic_fullyvirt_guest()
        g.installer = virtinst.PXEInstaller(type="xen", os_type="hvm", conn=g.conn)
        self._compare(g, "install-fullyvirt-pxe", True)

    def testInstallFVLiveCD(self):
        g = get_basic_fullyvirt_guest()
        g.installer = virtinst.LiveCDInstaller(type="xen", os_type="hvm", conn=g.conn, location="/dev/loop0")
        self._compare(g, "install-fullyvirt-livecd", False)

    def testXMLEscaping(self):
        g = get_basic_fullyvirt_guest()
        g.disks.append(virtinst.VirtualDisk("/tmp/ISO&'&s", type=virtinst.VirtualDisk.TYPE_FILE, size=5))
        self._compare(g, "misc-xml-escaping", True)


if __name__ == "__main__":
    unittest.main()
