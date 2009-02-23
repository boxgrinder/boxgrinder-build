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

import os.path
import unittest
import virtinst.CapabilitiesParser as capabilities

class TestCapabilities(unittest.TestCase):

    def _compareGuest(self, (arch, os_type, domains, features), guest):
        self.assertEqual(arch,            guest.arch)
        self.assertEqual(os_type,         guest.os_type)
        self.assertEqual(len(domains), len(guest.domains))
        for n in range(len(domains)):
            self.assertEqual(domains[n][0], guest.domains[n].hypervisor_type)
            self.assertEqual(domains[n][1], guest.domains[n].emulator)
            self.assertEqual(domains[n][2], guest.domains[n].machines)

        for n in features:
            self.assertEqual(features[n],        guest.features[n])

    def _testCapabilities(self, path, (host_arch, host_features), guests):
        caps = capabilities.parse(file(os.path.join("tests/capabilities-xml", path)).read())

        self.assertEqual(host_arch,     caps.host.arch)
        for n in host_features:
            self.assertEqual(host_features[n], caps.host.features[n])

        map(self._compareGuest, guests, caps.guests)

    def testCapabilities1(self):
        host = ( 'x86_64', {'vmx': capabilities.FEATURE_ON} )

        guests = [
            ( 'x86_64', 'xen',
              [['xen', None, []]], {} ),
            ( 'i686',   'xen',
              [['xen', None, []]], { 'pae': capabilities.FEATURE_ON } ),
            ( 'i686',   'hvm',
              [['xen', "/usr/lib64/xen/bin/qemu-dm", ['pc', 'isapc']]], { 'pae': capabilities.FEATURE_ON|capabilities.FEATURE_OFF } ),
            ( 'x86_64', 'hvm',
              [['xen', "/usr/lib64/xen/bin/qemu-dm", ['pc', 'isapc']]], {} )
        ]

        self._testCapabilities("capabilities-xen.xml", host, guests)

    def testCapabilities2(self):
        host = ( 'x86_64', {} )

        guests = [
            ( 'x86_64', 'hvm',
              [['qemu','/usr/bin/qemu-system-x86_64', ['pc', 'isapc']]], {} ),
            ( 'i686',   'hvm',
              [['qemu','/usr/bin/qemu', ['pc', 'isapc']]], {} ),
            ( 'mips',   'hvm',
              [['qemu','/usr/bin/qemu-system-mips', ['mips']]], {} ),
            ( 'mipsel', 'hvm',
              [['qemu','/usr/bin/qemu-system-mipsel', ['mips']]], {} ),
            ( 'sparc',  'hvm',
              [['qemu','/usr/bin/qemu-system-sparc', ['sun4m']]], {} ),
            ( 'ppc',    'hvm',
              [['qemu','/usr/bin/qemu-system-ppc', ['g3bw', 'mac99', 'prep']]], {} ),
        ]

        self._testCapabilities("capabilities-qemu.xml", host, guests)

    def testCapabilities3(self):
        host = ( 'i686', {} )

        guests = [
            ( 'i686',   'hvm',
              [['qemu','/usr/bin/qemu', ['pc', 'isapc']],
               ['kvm', '/usr/bin/qemu-kvm', ['pc', 'isapc']]], {} ),
            ( 'x86_64', 'hvm',
              [['qemu','/usr/bin/qemu-system-x86_64', ['pc', 'isapc']]], {} ),
            ( 'mips',   'hvm',
              [['qemu','/usr/bin/qemu-system-mips', ['mips']]], {} ),
            ( 'mipsel', 'hvm',
              [['qemu','/usr/bin/qemu-system-mipsel', ['mips']]], {} ),
            ( 'sparc',  'hvm',
              [['qemu','/usr/bin/qemu-system-sparc', ['sun4m']]], {} ),
            ( 'ppc',    'hvm',
              [['qemu','/usr/bin/qemu-system-ppc', ['g3bw', 'mac99', 'prep']]], {} ),
        ]

        self._testCapabilities("capabilities-kvm.xml", host, guests)

    def testCapabilities4(self):
        host = ( 'i686', { 'pae': capabilities.FEATURE_ON|capabilities.FEATURE_OFF } )

        guests = [
            ( 'i686', 'linux',
              [['test', None, []]],
              { 'pae': capabilities.FEATURE_ON|capabilities.FEATURE_OFF } ),
        ]

        self._testCapabilities("capabilities-test.xml", host, guests)

if __name__ == "__main__":
    unittest.main()
