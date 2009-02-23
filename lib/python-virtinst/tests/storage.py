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
from virtinst.Storage import StoragePool, StorageVolume
import libvirt

def _findFreePoolName(conn, namebase):

    i = 0
    while True:
        poolname = namebase + "-%d" % i
        try:
            StorageVolume.lookup_pool_by_name(conn=conn, pool_name=poolname)
            i += 1
        except:
            return poolname

def createPool(conn, ptype, poolname=None, format=None, tpath=None,
               spath=None, start=True):
    poolclass = StoragePool.get_pool_class(ptype)

    if poolname is None:
        poolname = _findFreePoolName(conn, str(ptype) + "-pool")

    pool_inst = poolclass(conn=conn, name=poolname)

    if hasattr(pool_inst, "host"):
        pool_inst.host = "some.random.hostname"
    if hasattr(pool_inst, "source_path"):
        pool_inst.source_path = spath or "/some/source/path"
    if hasattr(pool_inst, "target_path"):
        pool_inst.target_path = tpath or "/some/target/path"
    if format and hasattr(pool_inst, "format"):
        pool_inst.format = format

    return pool_inst.install(build=True, meter=None, create=start)

def createVol(poolobj, volname=None):
    volclass = StorageVolume.get_volume_for_pool(pool_object=poolobj)

    if volname == None:
        volname = poolobj.name() + "-vol"

    alloc = 5 * 1024 * 1024 * 1024
    cap = 10 * 1024 * 1024 * 1024
    vol_inst = volclass(name=volname, capacity=cap, allocation=alloc,
                        pool=poolobj)

    return vol_inst.install(meter=False)

class TestStorage(unittest.TestCase):

    def setUp(self):
        self.conn = libvirt.open("test:///default")

    def testDirPool(self):
        poolobj = createPool(self.conn, StoragePool.TYPE_DIR)
        createVol(poolobj)

    def testFSPool(self):
        poolobj = createPool(self.conn, StoragePool.TYPE_FS)
        createVol(poolobj)

    def testNetFSPool(self):
        poolobj = createPool(self.conn, StoragePool.TYPE_NETFS)
        createVol(poolobj)

    def testLVPool(self):
        poolobj = createPool(self.conn, StoragePool.TYPE_LOGICAL)
        createVol(poolobj)

    def testDiskPool(self):
        poolobj = createPool(self.conn, StoragePool.TYPE_DISK, format="dos")
        # Not implemented yet
        #volobj = createVol(poolobj)
        self.assertRaises(RuntimeError, createVol, poolobj)

    def testISCSIPool(self):
        poolobj = createPool(self.conn, StoragePool.TYPE_ISCSI)
        # Not supported
        #volobj = createVol(poolobj)
        self.assertRaises(RuntimeError, createVol, poolobj)

if __name__ == "__main__":
    unittest.main()

