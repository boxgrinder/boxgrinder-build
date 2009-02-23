#
# Classes for building disk device xml
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

import os, stat, statvfs
import subprocess
import libxml2
import logging
import libvirt

import _util
import Storage
from VirtualDevice import VirtualDevice
from virtinst import _virtinst as _

def _vdisk_create(path, size, kind, sparse = True):
    force_fixed = "raw"
    path = os.path.expanduser(path)
    if kind in force_fixed or not sparse:
        _type = kind + ":fixed"
    else:
        _type = kind + ":sparse"
    try:
        rc = subprocess.call([ '/usr/sbin/vdiskadm', 'create', '-t', _type,
            '-s', str(size), path ])
        return rc == 0
    except OSError:
        return False

class VirtualDisk(VirtualDevice):
    """
    Builds a libvirt domain disk xml description

    The VirtualDisk class is used for building libvirt domain xml descriptions
    for disk devices. If creating a disk object from an existing local block
    device or file, a path is all that should be required. If you want to
    create a local file, a size also needs to be specified.

    The remote case is a bit more complex. The options are:
        1. A libvirt virStorageVol instance (passed as 'volObject') for an
           existing storage volume.
        2. A virtinst L{StorageVolume} instance for creating a volume (passed
           as 'volInstall').
        3. An active connection ('conn') and a path to a storage volume on
           that connection.
        4. An active connection and a tuple of the form ("poolname",
           "volumename")
        5. An active connection and a path. The base of the path must
           point to the target path for an active pool.

    For cases 3 and 4, the lookup will be performed, and 'vol_object'
    will be set to the returned virStorageVol. For the last case, 'volInstall'
    will be populated for a StorageVolume instance. All the above cases also
    work on a local connection as well, the only difference being that
    option 3 won't neccessarily error out if the volume isn't found.

    __init__ and setting all properties performs lots of validation,
    and will throw ValueError's if problems are found.
    """

    DRIVER_FILE = "file"
    DRIVER_PHY = "phy"
    DRIVER_TAP = "tap"
    driver_names = [DRIVER_FILE, DRIVER_PHY, DRIVER_TAP]

    DRIVER_TAP_RAW = "aio"
    DRIVER_TAP_QCOW = "qcow"
    DRIVER_TAP_VMDK = "vmdk"
    DRIVER_TAP_VDISK = "vdisk"
    driver_types = [DRIVER_TAP_RAW, DRIVER_TAP_QCOW,
        DRIVER_TAP_VMDK, DRIVER_TAP_VDISK]

    DEVICE_DISK = "disk"
    DEVICE_CDROM = "cdrom"
    DEVICE_FLOPPY = "floppy"
    devices = [DEVICE_DISK, DEVICE_CDROM, DEVICE_FLOPPY]

    TYPE_FILE = "file"
    TYPE_BLOCK = "block"
    types = [TYPE_FILE, TYPE_BLOCK]

    def __init__(self, path=None, size=None, transient=False, type=None,
                 device=DEVICE_DISK, driverName=None, driverType=None,
                 readOnly=False, sparse=True, conn=None, volObject=None,
                 volInstall=None, volName=None, bus=None):
        """
        @param path: filesystem path to the disk image.
        @type path: C{str}
        @param size: size of local file to create in gigabytes
        @type size: C{int} or C{long} or C{float}
        @param transient: whether to keep disk around after guest install
        @type transient: C{bool}
        @param type: disk media type (file, block, ...)
        @type type: C{str}
        @param device: Emulated device type (disk, cdrom, floppy, ...)
        @type device: member of devices
        @param driverName: name of driver
        @type driverName: member of driver_names
        @param driverType: type of driver
        @type driverType: member of driver_types
        @param readOnly: Whether emulated disk is read only
        @type readOnly: C{bool}
        @param sparse: Create file as a sparse file
        @type sparse: C{bool}
        @param conn: Connection disk is being installed on
        @type conn: libvirt.virConnect
        @param volObject: libvirt storage volume object to use
        @type volObject: libvirt.virStorageVol
        @param volInstall: StorageVolume instance to build for new storage
        @type volInstall: L{StorageVolume}
        @param volName: Existing StorageVolume lookup information,
                        (parent pool name, volume name)
        @type volName: C{tuple} of (C{str}, C{str})
        @param bus: Emulated bus type (ide, scsi, virtio, ...)
        @type bus: C{str}
        """

        VirtualDevice.__init__(self, conn=conn)

        self._path = None
        self._size = None
        self._type = None
        self._device = None
        self._sparse = None
        self._readOnly = None
        self._vol_object = None
        self._vol_install = None
        self._bus = None

        # XXX: No property methods for these
        self.transient = transient
        self._driverName = driverName
        self._driverType = driverType
        self.target = None

        self.set_read_only(readOnly, validate=False)
        self.set_sparse(sparse, validate=False)
        self.set_type(type, validate=False)
        self.set_device(device, validate=False)
        self._set_path(path, validate=False)
        self._set_size(size, validate=False)
        self._set_vol_object(volObject, validate=False)
        self._set_vol_install(volInstall, validate=False)
        self._set_bus(bus, validate=False)

        if volName:
            self.__lookup_vol_name(volName)

        self.__validate_params()


    def __repr__(self):
        """
        prints a simple string representation for the disk instance
        """
        return "%s:%s" %(self.type, self.path)



    def _get_path(self):
        return self._path
    def _set_path(self, val, validate=True):
        if val is not None:
            self._check_str(val, "path")
            val = os.path.abspath(val)
        self.__validate_wrapper("_path", val, validate)
    path = property(_get_path, _set_path)

    def _get_size(self):
        return self._size
    def _set_size(self, val, validate=True):
        if val is not None:
            if type(val) not in [int, float, long] or val < 0:
                raise ValueError, _("'size' must be a number greater than 0.")
        self.__validate_wrapper("_size", val, validate)
    size = property(_get_size, _set_size)

    def get_type(self):
        return self._type
    def set_type(self, val, validate=True):
        if val is not None:
            self._check_str(val, "type")
            if val not in self.types:
                raise ValueError, _("Unknown storage type '%s'" % val)
        self.__validate_wrapper("_type", val, validate)
    type = property(get_type, set_type)

    def get_device(self):
        return self._device
    def set_device(self, val, validate=True):
        self._check_str(val, "device")
        if val not in self.devices:
            raise ValueError, _("Unknown device type '%s'" % val)
        self.__validate_wrapper("_device", val, validate)
    device = property(get_device, set_device)

    def get_driver_name(self):
        return self._driverName
    def set_driver_name(self, val):
        self._driverName = val
    driver_name = property(get_driver_name, set_driver_name)

    def get_driver_type(self):
        return self._driverType
    def set_driver_type(self, val):
        self._driverType = val
    driver_type = property(get_driver_type, set_driver_type)

    def get_sparse(self):
        return self._sparse
    def set_sparse(self, val, validate=True):
        self._check_bool(val, "sparse")
        self.__validate_wrapper("_sparse", val, validate)
    sparse = property(get_sparse, set_sparse)

    def get_read_only(self):
        return self._readOnly
    def set_read_only(self, val, validate=True):
        self._check_bool(val, "read_only")
        self.__validate_wrapper("_readOnly", val, validate)
    read_only = property(get_read_only, set_read_only)

    def _get_vol_object(self):
        return self._vol_object
    def _set_vol_object(self, val, validate=True):
        if val is not None and not isinstance(val, libvirt.virStorageVol):
            raise ValueError, _("vol_object must be a virStorageVol instance")
        self.__validate_wrapper("_vol_object", val, validate)
    vol_object = property(_get_vol_object, _set_vol_object)

    def _get_vol_install(self):
        return self._vol_install
    def _set_vol_install(self, val, validate=True):
        if val is not None and not isinstance(val, Storage.StorageVolume):
            raise ValueError, _("vol_install must be a StorageVolume "
                                " instance.")
        self.__validate_wrapper("_vol_install", val, validate)
    vol_install = property(_get_vol_install, _set_vol_install)

    def _get_bus(self):
        return self._bus
    def _set_bus(self, val, validate=True):
        if val is not None:
            self._check_str(val, "bus")
        self.__validate_wrapper("_bus", val, validate)
    bus = property(_get_bus, _set_bus)

    # Validation assistance methods

    # Initializes attribute if it hasn't been done, then validates args.
    # If validation fails, reset attribute to original value and raise error
    def __validate_wrapper(self, varname, newval, validate=True):
        try:
            orig = getattr(self, varname)
        except:
            orig = newval
        setattr(self, varname, newval)
        if validate:
            try:
                self.__validate_params()
            except:
                setattr(self, varname, orig)
                raise

    def __set_dev_type(self):
        """
        Detect disk 'type' () from passed storage parameters
        """

        dtype = None
        if self.vol_object:
            # vol info is [ vol type (file or block), capacity, allocation ]
            t = self.vol_object.info()[0]
            if t == libvirt.VIR_STORAGE_VOL_FILE:
                dtype = self.TYPE_FILE
            elif t == libvirt.VIR_STORAGE_VOL_BLOCK:
                dtype = self.TYPE_BLOCK
            else:
                raise ValueError, _("Unknown storage volume type.")
        elif self.vol_install:
            if isinstance(self.vol_install, Storage.FileVolume):
                dtype = self.TYPE_FILE
            else:
                # All others should be using TYPE_BLOCK (hopefully)
                dtype = self.TYPE_BLOCK
        elif self.path:
            if stat.S_ISBLK(os.stat(self.path)[stat.ST_MODE]):
                dtype = self.TYPE_BLOCK
            else:
                dtype = self.TYPE_FILE
            if _util.is_vdisk(self.path):
                self._driverName = self.DRIVER_TAP
                self._driverType = self.DRIVER_TAP_VDISK

        if self.type is None:
            logging.debug("Detected storage as type '%s'" % dtype)
        elif dtype != self.type:
            raise ValueError(_("Passed type '%s' does not match detected "
                               "storage type '%s'" % (self.type, dtype)))
        self.set_type(dtype, validate=False)

    def __lookup_vol_name(self, name_tuple):
        """
        lookup volume via tuple passed via __init__'s volName parameter
        """
        if type(name_tuple) is not tuple or len(name_tuple) != 2 \
           or (type(name_tuple[0]) is not type(name_tuple[1]) is not str):
            raise ValueError(_("volName must be a tuple of the form "
                               "('poolname', 'volname')"))
        if not self.conn:
            raise ValueError(_("'volName' requires a passed connection."))
        if not _util.is_storage_capable(self.conn):
            raise ValueError(_("Connection does not support storage lookup."))
        try:
            pool = self.conn.storagePoolLookupByName(name_tuple[0])
            self._set_vol_object(pool.storageVolLookupByName(name_tuple[1]),
                                validate=False)
        except Exception, e:
            raise ValueError(_("Couldn't lookup volume object: %s" % str(e)))

    def __storage_specified(self):
        """
        Return bool representing if managed storage parameters have
        been explicitly specified or filled in
        """
        return (self.vol_object != None or self.vol_install != None)

    def __check_if_path_managed(self):
        """
        Determine if we can use libvirt storage apis to create or lookup
        'self.path'
        """
        vol = None
        verr = None
        pool = _util.lookup_pool_by_path(self.conn,
                                         os.path.dirname(self.path))
        if pool:
            # Is pool running?
            if pool.info()[0] != libvirt.VIR_STORAGE_POOL_RUNNING:
                pool = None

            try:
                vol = self.conn.storageVolLookupByPath(self.path)
            except Exception, e:
                try:
                    try:
                        # Pool may need to be refreshed, but if it errors,
                        # invalidate it
                        pool.refresh(0)
                    except:
                        pool = None
                        raise
                    vol = self.conn.storageVolLookupByPath(self.path)
                except Exception, e:
                    verr = str(e)

        if not vol:
            # Path wasn't a volume. See if base of path is a managed
            # pool, and if so, setup a StorageVolume object
            if pool:
                if self.size == None:
                    raise ValueError(_("Size must be specified for non "
                                       "existent volume path '%s'" % \
                                        self.path))
                logging.debug("Path '%s' is target for pool '%s'. "
                              "Creating volume '%s'." % \
                              (os.path.dirname(self.path), pool.name(),
                               os.path.basename(self.path)))
                volclass = Storage.StorageVolume.get_volume_for_pool(pool_object=pool)
                cap = (self.size * 1024 * 1024 * 1024)
                if self.sparse:
                    alloc = 0
                else:
                    #alloc = cap
                    # XXX: disable setting managed storage as nonsparse
                    # XXX: since it hoses libvirtd (for now)
                    alloc = 0
                vol = volclass(name=os.path.basename(self.path),
                               capacity=cap, allocation=alloc, pool=pool)
                self._set_vol_install(vol, validate=False)
            elif self._is_remote():
                raise ValueError(_("'%s' is not managed on remote "
                                   "host: %s" % (self.path, verr)))
        else:
            self._set_vol_object(vol, validate=False)


    def __sync_params(self):
        """
        Sync some parameters between storage objects and the older
        VirtualDisk fields
        """

        newpath = None
        if self.vol_object:
            newpath = self.vol_object.path()
        elif self.vol_install:
            newpath = _util.get_xml_path(self.vol_install.pool.XMLDesc(0),
                                         "/pool/target/path") + \
                      self.vol_install.name

        if newpath and newpath != self.path:
            logging.debug("Overwriting 'path' from passed volume object.")
            self._set_path(newpath, validate=False)

        if self.vol_install:
            newsize = self.vol_install.capacity/1024.0/1024.0/1024.0
            if self.size != newsize:
                logging.debug("Overwriting 'size' with value from "
                              "StorageVolume")
                self._set_size(newsize, validate=False)

        # Remove this piece when storage volume creation is async
        if self.sparse and self.vol_install and \
           self.vol_install.allocation != 0:
            logging.debug("Setting vol_install allocation to 0 (sparse).")
            self.vol_install.allocation = 0

    def __validate_params(self):
        """
        function to validate all the complex interaction between the various
        disk parameters.
        """

        # if storage capable, try to lookup path
        # if no obj: if remote, error
        storage_capable = False
        if self.conn:
            storage_capable = _util.is_storage_capable(self.conn)

        if not storage_capable and self._is_remote():
            raise ValueError, _("Connection doesn't support remote storage.")

        # If the user didn't pass storage parameters, try to determine them
        # from the passed path
        if storage_capable and self.path is not None \
           and not self.__storage_specified():
            self.__check_if_path_managed()

        # Sync parameters between VirtualDisk and potentially passed
        # storage objects.
        self.__sync_params()

        # One small caveat: if self.path isn't set at this point, we are
        # basically done.
        if self.path is None:
            if self.device != self.DEVICE_FLOPPY and \
               self.device != self.DEVICE_CDROM:
                raise ValueError, _("Device type '%s' requires a path") % \
                                  self.device
            return True


        # The main distinctions from this point forward:
        # Are we doing storage API operations or local media checks?
        managed_storage = self.__storage_specified() or self.path is None
        # Do we need to create the storage?
        create_media = not ((managed_storage and self.vol_object) or \
                            (self.path and os.path.exists(self.path)))

        if self._is_remote() and not managed_storage:
            raise ValueError, _("Must specify libvirt managed storage if on "
                                "a remote connection")

        # If not creating the storage, our job is easy
        if not create_media:
            # Make sure we have access to the local path
            if not managed_storage:
                if os.path.isdir(self.path) and not _util.is_vdisk(self.path):
                    # vdisk _is_ a directory.
                    raise ValueError(_("The path '%s' must be a file or a "
                                       "device, not a directory") % self.path)
                # XXX: Any selinux validation checks should go here

            self.__set_dev_type()
            return True


        if self.device == self.DEVICE_FLOPPY or \
           self.device == self.DEVICE_CDROM:
            raise ValueError, _("Cannot create storage for %s device.") % \
                                self.device

        if not managed_storage:
            if self.type is self.TYPE_BLOCK:
                raise ValueError, _("Local block device path must exist.")
            self.set_type(self.TYPE_FILE, validate=False)

            # Path doesn't exist: make sure we have write access to dir
            if not os.access(os.path.dirname(self.path), os.W_OK):
                raise ValueError, _("No write access to directory '%s'") % \
                                    os.path.dirname(self.path)
            if self.size is None:
                raise ValueError, _("size is required for non-existent disk "
                                    "'%s'" % self.path)
        else:
            self.__set_dev_type()

        # Applicable for managed or local storage
        ret = self.is_size_conflict()
        if ret[0]:
            raise ValueError, ret[1]
        elif ret[1]:
            logging.warn(ret[1])



    def setup(self, progresscb=None):
        """
        Build storage (if required)

        If storage doesn't exist (a non-existent file 'path', or 'vol_install'
        was specified), we create it.

        @param progresscb: progress meter
        @type progresscb: instanceof urlgrabber.BaseMeter
        """
        if self.vol_object:
            return
        elif self.vol_install:
            self._set_vol_object(self.vol_install.install(meter=progresscb),
                                 validate=False)
            return
        elif (self.type == VirtualDisk.TYPE_FILE and self.path is not None
             and not os.path.exists(self.path)):
            size_bytes = long(self.size * 1024L * 1024L * 1024L)

            if progresscb:
                progresscb.start(filename=self.path,size=long(size_bytes), \
                                 text=_("Creating storage file..."))

            if _util.is_vdisk(self.path):
                progresscb.update(1024)
                if (not _vdisk_create(self.path, size_bytes, "vmdk",
                    self.sparse)):
                    raise RuntimeError, _("Error creating vdisk %s" % self.path)
                self._driverName = self.DRIVER_TAP
                self._driverType = self.DRIVER_TAP_VDISK
                progresscb.end(self.size)
                return

            fd = None
            try:
                try:
                    fd = os.open(self.path, os.O_WRONLY | os.O_CREAT)
                    if self.sparse:
                        os.ftruncate(fd, size_bytes)
                        if progresscb:
                            progresscb.update(self.size)
                    else:
                        buf = '\x00' * 1024 * 1024 # 1 meg of nulls
                        for i in range(0, long(self.size * 1024L)):
                            os.write(fd, buf)
                            if progresscb:
                                progresscb.update(long(i * 1024L * 1024L))
                except OSError, e:
                    raise RuntimeError, _("Error creating diskimage %s: %s" % \
                                        (self.path, str(e)))
            finally:
                if fd is not None:
                    os.close(fd)
                if progresscb:
                    progresscb.end(size_bytes)
        # FIXME: set selinux context?

    def get_xml_config(self, disknode=None):
        """
        @param disknode: device name in host (xvda, hdb, etc.). self.target
                         takes precedence.
        @type disknode: C{str}
        """
        typeattr = 'file'
        if self.type == VirtualDisk.TYPE_BLOCK:
            typeattr = 'dev'

        if self.target:
            disknode = self.target
        if not disknode:
            raise ValueError(_("'disknode' or self.target must be set!"))

        path = None
        if self.vol_object:
            path = self.vol_object.path()
        elif self.path:
            path = self.path
        if path:
            path = _util.xml_escape(path)

        ret = "    <disk type='%(type)s' device='%(device)s'>\n" % { "type": self.type, "device": self.device }
        if not(self.driver_name is None):
            if self.driver_type is None:
                ret += "      <driver name='%(name)s'/>\n" % { "name": self.driver_name }
            else:
                ret += "      <driver name='%(name)s' type='%(type)s'/>\n" % { "name": self.driver_name, "type": self.driver_type }
        if path is not None:
            ret += "      <source %(typeattr)s='%(disk)s'/>\n" % { "typeattr": typeattr, "disk": path }

        bus_xml = ""
        if self.bus is not None:
            bus_xml = " bus='%s'" % self.bus
        ret += "      <target dev='%s'" % disknode + \
                      "%s" % bus_xml + \
                      "/>\n"

        ro = self.read_only

        if self.device == self.DEVICE_CDROM:
            ro = True
        if ro:
            ret += "      <readonly/>\n"
        ret += "    </disk>"
        return ret

    def is_size_conflict(self):
        """
        reports if disk size conflicts with available space

        returns a two element tuple:
            1. first element is True if fatal conflict occurs
            2. second element is a string description of the conflict or None
        Non fatal conflicts (sparse disk exceeds available space) will
        return (False, "description of collision")
        """

        if self.vol_install:
            return self.vol_install.is_size_conflict()

        if self.vol_object or self.size is None or not self.path \
           or os.path.exists(self.path) or self.type != self.TYPE_FILE:
            return (False, None)

        ret = False
        msg = None
        vfs = os.statvfs(os.path.dirname(self.path))
        avail = vfs[statvfs.F_FRSIZE] * vfs[statvfs.F_BAVAIL]
        need = long(self.size * 1024L * 1024L * 1024L)
        if need > avail:
            if self.sparse:
                msg = _("The filesystem will not have enough free space"
                        " to fully allocate the sparse file when the guest"
                        " is running.")
            else:
                ret = True
                msg = _("There is not enough free space to create the disk.")


            if msg:
                msg += _(" %d M requested > %d M available") % \
                        ((need / (1024*1024)), (avail / (1024*1024)))
        return (ret, msg)

    def is_conflict_disk(self, conn):
        """
        check if specified storage is in use by any other VMs on passed
        connection.

        @param conn: connection to check for collisions on
        @type conn: libvirt.virConnect

        @return: True if a collision, False otherwise
        @rtype: C{bool}
        """
        vms = []
        # get working domain's name
        ids = conn.listDomainsID()
        for i in ids:
            try:
                vm = conn.lookupByID(i)
                vms.append(vm)
            except libvirt.libvirtError:
                # guest probably in process of dieing
                logging.warn("Failed to lookup domain id %d" % i)
        # get defined domain
        names = conn.listDefinedDomains()
        for name in names:
            try:
                vm = conn.lookupByName(name)
                vms.append(vm)
            except libvirt.libvirtError:
                # guest probably in process of dieing
                logging.warn("Failed to lookup domain name %s" % name)

        if self.vol_object:
            path = self.vol_object.path()
        else:
            path = self.path

        if not path:
            return False

        count = 0
        for vm in vms:
            doc = None
            try:
                doc = libxml2.parseDoc(vm.XMLDesc(0))
            except:
                continue
            ctx = doc.xpathNewContext()
            try:
                try:
                    count += ctx.xpathEval("count(/domain/devices/disk/source[@dev='%s'])" % path)
                    count += ctx.xpathEval("count(/domain/devices/disk/source[@file='%s'])" % path)
                except:
                    continue
            finally:
                if ctx is not None:
                    ctx.xpathFreeContext()
                if doc is not None:
                    doc.freeDoc()
        if count > 0:
            return True
        else:
            return False

    def _get_target_type(self):
        """
        Returns the suggested disk target prefix (hd, xvd, sd ...) from
        the passed parameters.
        @returns: str prefix, or None if no reasonable guess can be made
        """
        if self.bus == "virtio":
            return ("vd", 16)
        elif self.bus == "scsi" or self.bus == "usb":
            return ("sd", 16)
        elif self.bus == "xen":
            return ("xvd", 16)
        elif self.bus == "ide":
            return ("hd", 4)
        elif self.bus == "floppy" or self.device == self.DEVICE_FLOPPY:
            return ("fd", 2)
        else:
            return (None, None)

    def generate_target(self, skip_targets):
        """
        Generate target device ('hda', 'sdb', etc..) for disk, excluding
        any targets in list 'skip_targets'. Sets self.target, and returns the
        generated value
        @param used_targets: list of targets to exclude
        @type used_targets: C{list}
        @raise ValueError: can't determine target type, no targets available
        @returns generated target
        @rtype C{str}
        """

        # Only use these targets if there are no other options
        except_targets = ["hdc"]

        prefix, maxnode = self._get_target_type()
        if prefix is None:
            raise ValueError(_("Cannot determine device bus/type."))

        # Special case: IDE cdrom must be hdc
        if self.device == self.DEVICE_CDROM and prefix == "hd":
            if "hdc" not in skip_targets:
                self.target = "hdc"
                return self.target
            raise ValueError(_("IDE CDROM must use 'hdc', but target in use."))

        # Regular scanning
        for i in range(maxnode):
            gen_t = "%s%c" % (prefix, ord('a') + i)
            if gen_t in except_targets:
                continue
            if gen_t not in skip_targets:
                self.target = gen_t
                return self.target

        # Check except_targets for any options
        for t in except_targets:
            if t.startswith(prefix) and t not in skip_targets:
                self.target = t
                return self.target
        raise ValueError(_("No more space for disks of type '%s'" % prefix))


class XenDisk(VirtualDisk):
    """
    Back compat class to avoid ABI break.
    """
    pass
