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
import virtinst
from virtinst import VirtualDisk

# Test helpers
from storage import createPool, createVol

import unittest
import logging
import traceback
import os

# Template for adding arguments to test
# { 'label' : { \
#       'VAR' : { \
#           'invalid' : [param],
#           'valid'   : [param]},
#       '__init__'  : { \
#           'invalid' : [{'initparam':val}],
#           'valid'   : [{'initparam':val}]}
#
#   Anything in 'valid' should throw no error
#   Anything in 'invalid' should throw ValueError or TypeError

# We install several storage pools on the connection to ensure
# we aren't bumping up against errors in that department.
logging.debug("Starting 'validation' storage setup.")
testconn = libvirt.open("test:///default")

offdskpaths = [ "/dev", ]
for path in offdskpaths:
    createPool(testconn, virtinst.Storage.StoragePool.TYPE_DISK,
               tpath=path, start=False, format="dos")

dirpaths = [ "/var/lib/libvirt/images", "/", "/tmp" ]
for path in dirpaths:
    createPool(testconn, virtinst.Storage.StoragePool.TYPE_DIR,
               tpath=path, start=True)

dskpaths = [ "/somedev", "/dev/disk/by-uuid" ]
for path in dskpaths:
    createPool(testconn, virtinst.Storage.StoragePool.TYPE_DISK,
               format="dos", tpath=path, start=False)

# Create a usable pool/vol pairs
p = createPool(testconn, virtinst.Storage.StoragePool.TYPE_DIR,
               tpath="/pool-exist", start=True, poolname="pool-exist")
dirvol = createVol(p, "vol-exist")
volinst = virtinst.Storage.StorageVolume(pool=p, name="somevol", capacity=1)
logging.debug("Ending 'validation' storage setup.")

args = { \

'guest' : { \
    'name'  : {
        'invalid' : ['123456789', 'im_invalid!', '', 0,
                     'verylongnameverylongnameverylongnamevery'
                     'longnameveryvery'],
        'valid'   : ['Valid_name.01'] },
    'memory' : { \
        'invalid' : [-1, 0, ''],
        'valid'   : [200, 2000] },
    'maxmemory' : { \
        'invalid' : [-1, 0, ''],
        'valid'   : [200, 2000], },
    'uuid'      : { \
        'invalid' : [ '', 0, '1234567812345678123456781234567x'],
        'valid'   : ['12345678123456781234567812345678',
                     '12345678-1234-1234-ABCD-ABCDEF123456']},
    'vcpus'     : { \
        'invalid' : [-1, 0, 1000, ''],
        'valid'   : [ 1, 32 ] },
    'graphics'  : { \
        'invalid' : ['', True, 'unknown', {}, ('', '', '', 0),
                     ('','','', 'longerthan16chars'),
                     ('','','','invalid!!ch@r')],
        'valid'   : [False, 'sdl', 'vnc', (True, 'sdl', '', 'key_map-2'),
                     {'enabled' : True, 'type':'vnc', 'opts':5900} ]},
    'type'      : { \
        'invalid' : [],
        'valid'   : ['sometype'] },
    'cdrom'     : {
        'invalid' : ['', 0, '/somepath'],
        'valid'   : ['/dev/loop0'] }
    },

'fvguest'  : { \
    'os_type'   : { \
        'invalid' : ['notpresent',0,''],
        'valid'   : ['other', 'windows', 'unix', 'linux']},
    'os_variant': { \
        'invalid' : ['', 0, 'invalid'],
        'valid'   : ['rhel5', 'sles10']},
    },

'disk' : { \
    'init_conns' : [ testconn, None ],
    '__init__' : { \
        'invalid' : [{ 'path' : 0},
                     { 'path' : '/root' },
                     { 'path' : 'valid', 'size' : None },
                     { 'path' : "valid", 'size' : 'invalid' },
                     { 'path' : 'valid', 'size' : -1},
                     { 'path' : 'notblock', 'type' : VirtualDisk.TYPE_BLOCK},
                     { 'path' :'/dev/null', 'type' : VirtualDisk.TYPE_BLOCK},
                     { 'path' : None },
                     { 'path' : "noexist", 'size' : 900000, 'sparse' : False },
                     { 'path' : "noexist", 'type' : VirtualDisk.DEVICE_CDROM},
                     { 'volName' : ("pool-exist", "vol-exist")},
                     { 'conn' : testconn, 'volName' : ("pool-noexist",
                                                       "vol-exist")},
                     { 'conn' : testconn, 'volName' : ("pool-exist",
                                                       "vol-noexist")},
                     { 'conn' : testconn, 'volName' : ( 1234,
                                                       "vol-noexist")},
                    ],

        'valid' :   [{ 'path' : '/dev/loop0' },
                     { 'path' : 'nonexist', 'size' : 1 },
                     { 'path' :'/dev/null'},
                     { 'path' : None, 'device' : VirtualDisk.DEVICE_CDROM},
                     { 'path' : None, 'device' : VirtualDisk.DEVICE_FLOPPY},
                     { 'conn' : testconn, 'volName' : ("pool-exist",
                                                       "vol-exist")},
                     { 'conn' : testconn, 'path' : "/pool-exist/vol-exist" },
                     { 'conn' : testconn, 'path' : "/pool-exist/vol-noexist",
                       'size' : 1 },
                     { 'conn' : testconn, 'volInstall': volinst},
                    ]
                },
},

'installer' : { \
    'init_conns' : [ testconn, None ],
    'boot' : { \
        'invalid' : ['', 0, ('1element'), ['1el', '2el', '3el'],
                     {'1element': '1val'},
                     {'kernel' : 'a', 'wronglabel' : 'b'}],
        'valid'   : [('kern', 'init'), ['kern', 'init'],
                     { 'kernel' : 'a', 'initrd' : 'b'}]},
    'extraargs' : { \
        'invalid' : [],
        'valid'   : ['someargs']}, },

'distroinstaller' : { \
    'init_conns' : [ testconn, None ],
    'location'  : { \
        'invalid' : ['nogood', 'http:/nogood', [], None,
                     ("pool-noexist", "vol-exist"),
                     ("pool-exist", "vol-noexist"),
                    ],
        'valid'   : ['/dev/null', 'http://web', 'ftp://ftp', 'nfs:nfsserv',
                     ("pool-exist", "vol-exist"),
                    ]}},

'network'   : { \
    'init_conns' : [ testconn, None ],
    '__init__'  : { \
        'invalid' : [ {'macaddr':0}, {'macaddr':''}, {'macaddr':'$%XD'},
                      {'type':'network'} ],
        'valid'   : []} },

'clonedesign' : {
    'original_guest' :{
        'invalid' : ['', 0, 'invalid_name&',
                     '123456781234567812345678123456789'],
        'valid'   : ['some.valid-name_1', '12345678123456781234567812345678']},
    'clone_name': { 'invalid' : [0],
                    'valid'   : ['some.valid-name_9']},
    'clone_uuid': { 'invalid' : [0],
                    'valid'   : ['12345678123456781234567812345678']},
    'clone_mac' : { 'invalid' : ['badformat'],
                    'valid'   : ['AA:BB:CC:DD:EE:FF']},
    'clone_bs'  : { 'invalid' : [], 'valid'   : ['valid']}}
}

class TestValidation(unittest.TestCase):

    def _getInitConns(self, label):
        if args[label].has_key("init_conns"):
            return args[label]["init_conns"]
        return [testconn]

    def _runObjInit(self, testclass, valuedict, defaultsdict=None):
        if defaultsdict:
            for key in defaultsdict.keys():
                if not valuedict.has_key(key):
                    valuedict[key] = defaultsdict.get(key)
        testclass(*(), **valuedict)

    def _testInvalid(self, name, obj, testclass, paramname, paramvalue):
        try:
            if paramname == '__init__':
                self._runObjInit(testclass, paramvalue)
            else:
                setattr(obj, paramname, paramvalue)

            msg = ("Expected TypeError or ValueError: None Raised.\n"
                   "For '%s' object, paramname '%s', val '%s':" %
                   (name, paramname, paramvalue))
            raise AssertionError, msg

        except AssertionError:
            raise
        except ValueError:
            # This is an expected error
            pass
        except TypeError:
            # This is an expected error
            pass
        except Exception, e:
            msg = ("Unexpected exception raised: %s\n" % e +
                   "Original traceback was: \n%s\n" % traceback.format_exc() +
                   "For '%s' object, paramname '%s', val '%s':" %
                   (name, paramname, paramvalue))
            raise AssertionError, msg

    def _testValid(self, name, obj, testclass, paramname, paramvalue):

        try:
            if paramname is '__init__':
                conns = self._getInitConns(name)
                if paramvalue.has_key("conn"):
                    conns = [paramvalue["conn"]]
                for conn in conns:
                    paramvalue["conn"] = conn
                    self._runObjInit(testclass, paramvalue)
            else:
                setattr(obj, paramname, paramvalue)
        except Exception, e:
            msg = ("Validation case failed, expected success.\n" +
                   "Exception received was: %s\n" % e +
                   "Original traceback was: \n%s\n" % traceback.format_exc() +
                   "For '%s' object, paramname '%s', val '%s':" %
                   (name, paramname, paramvalue))
            raise AssertionError, msg

    def _testArgs(self, obj, testclass, name, exception_check=None):
        """@obj Object to test parameters against
           @testclass Full class to test initialization against
           @name String name indexing args"""
        logging.debug("Testing '%s'" % name)
        testdict = args[name]

        for paramname in testdict.keys():
            if paramname == "init_conns":
                continue

            for val in testdict[paramname]['invalid']:
                self._testInvalid(name, obj, testclass, paramname, val)

            for val in testdict[paramname]['valid']:
                if exception_check:
                    if exception_check(obj, paramname, val):
                        continue
                self._testValid(name, obj, testclass, paramname, val)


    # Actual Tests
    def testGuestValidation(self):
        PVGuest = virtinst.ParaVirtGuest(connection=testconn,
                                         type="xen")
        self._testArgs(PVGuest, virtinst.Guest, 'guest')

    def testDiskValidation(self):
        disk = VirtualDisk("/dev/loop0")
        self._testArgs(disk, VirtualDisk, 'disk')

    def testFVGuestValidation(self):
        FVGuest = virtinst.FullVirtGuest(connection=testconn,
                                         type="xen")
        self._testArgs(FVGuest, virtinst.FullVirtGuest, 'fvguest')

    def testNetworkValidation(self):
        network = virtinst.VirtualNetworkInterface(conn=testconn)
        self._testArgs(network, virtinst.VirtualNetworkInterface, 'network')

        # Test MAC Address collision
        hostmac = virtinst.util.get_host_network_devices()
        if len(hostmac) is not 0:
            hostmac = hostmac[0][4]

        for params in ({'macaddr' : hostmac},):
            network = virtinst.VirtualNetworkInterface(*(), **params)
            self.assertRaises(RuntimeError, network.setup, \
                              testconn)

        # Test dynamic MAC/Bridge success
        try:
            network = virtinst.VirtualNetworkInterface()
            network.setup(testconn)
        except Exception, e:
            raise AssertionError, \
                "Network setup with no params failed, expected success." + \
                " Exception was: %s: %s" % (str(e), "".join(traceback.format_exc()))

    def testDistroInstaller(self):
        def exception_check(obj, paramname, paramvalue):
            if paramname == "location":
                # Skip NFS test as non-root
                if paramvalue[0:3] == "nfs" and os.geteuid() != 0:
                    return True

                # Don't pass a tuple location if installer has no conn
                if not obj.conn and type(paramvalue) == tuple:
                    return True

            return False

        label = 'distroinstaller'
        for conn in self._getInitConns(label):
            dinstall = virtinst.DistroInstaller(conn=conn)
            self._testArgs(dinstall, virtinst.DistroInstaller, 'installer',
                           exception_check)
            self._testArgs(dinstall, virtinst.DistroInstaller, label,
                           exception_check)

    def testCloneManager(self):
        label = 'clonedesign'
        for conn in self._getInitConns(label):
            cman = virtinst.CloneManager.CloneDesign(conn)
            self._testArgs(cman, virtinst.CloneManager.CloneDesign, label)


if __name__ == "__main__":
    unittest.main()
