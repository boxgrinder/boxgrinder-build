#
# Copyright 2008 Red Hat, Inc.
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
"""
Classes for building and installing libvirt storage xml

General workflow for the different storage objects:

    1. Storage Pool:

    Pool type options can be exposed to a user via the static function
    L{StoragePool.get_pool_types}. Any selection can be fed back into
    L{StoragePool.get_pool_class} to get the particular volume class to
    instantiate. From here, values can be set at init time or via
    properties post init.

    Different pool types have different options and
    requirements, so using getattr() is probably the best way to check
    for parameter availability.

    2) Storage Volume:

    There are a few options for determining what pool volume class to use:
        - Pass the pools type for L{StoragePool.get_volume_for_pool}
        - Pass the pool object or name to L{StorageVolume.get_volume_for_pool}

    These will give back the appropriate class to instantiate. For most cases,
    all that's needed is a name and capacity, the rest will be filled in.

@see: U{http://libvirt.org/storage.html}
"""


import libvirt

import re
import logging
from xml.sax.saxutils import escape

import _util
from virtinst import _virtinst as _

DEFAULT_DEV_TARGET = "/dev"
DEFAULT_LVM_TARGET_BASE = "/dev/"
DEFAULT_DIR_TARGET_BASE = "/var/lib/libvirt/images/"
DEFAULT_ISCSI_TARGET = "/dev/disk/by-path"

# Pools:
#   DirectoryPool         : A flat filesystem directory
#   FilesystemPool        : A formatted partition
#   NetworkFilesystemPool : NFS
#   LogicalPool           : LVM Volume Group
#   DiskPool              : Raw disk
#   iSCSIPool             : iSCSI

class StorageObject(object):
    """
    Base class for building any libvirt storage object.

    Mostly meaningless to directly instantiate.
    """

    TYPE_POOL   = "pool"
    TYPE_VOLUME = "volume"

    def __init__(self, object_type, name, conn=None):
        """
        Initialize storage object parameters
        """
        if object_type not in [self.TYPE_POOL, self.TYPE_VOLUME]:
            raise ValueError, _("Unknown storage object type: %s") % type
        self._object_type = object_type
        self._conn = None
        if conn is not None:
            self.conn = conn

        self.name = name

        # Initialize all optional properties
        self._perms = None


    ## Properties
    def get_object_type(self):
        # 'pool' or 'volume'
        return self._object_type
    object_type = property(get_object_type)
    def get_type(self):
        raise RuntimeError, "Must be implemented in child class."
    type = property(get_type, doc=\
    """
    type of the underlying object. could be "dir" for a pool, etc.
    """)

    def get_conn(self):
        return self._conn
    def set_conn(self, val):
        if not isinstance(val, libvirt.virConnect):
            raise ValueError(_("'conn' must be a libvirt connection object."))
        if not _util.is_storage_capable(val):
            raise ValueError(_("Passed connection is not libvirt storage "
                               "capable"))
        self._conn = val
    conn = property(get_conn, set_conn, doc="""
    Libvirt connection to check object against/install on
    """)

    def get_name(self):
        return self._name
    def set_name(self, val):
        if type(val) is not type("string") or len(val) > 50 or len(val) == 0:
            raise ValueError, _("Storage object name must be a string " +
                                "between 0 and 50 characters")
        if re.match("^[0-9]+$", val):
            raise ValueError, _("Storage object name can not be only " +
                                "numeric characters")
        if re.match("^[a-zA-Z0-9._-]+$", val) == None:
            raise ValueError, _("Storage object name can only contain " +
                                "alphanumeric, '_', '.', or '-' characters")

        # Check that name doesn't collide with other storage objects
        self._check_name_collision(val)
        self._name = val
    name = property(get_name, set_name, doc="""
    Name of the storage object
    """)

    # Get/Set methods for use by some objects. Will register where applicable
    def get_perms(self):
        return self._perms
    def set_perms(self, val):
        if type(val) is not dict:
            raise ValueError(_("Permissions must be passed as a dict object"))
        for key in ["mode", "owner", "group", "label"]:
            if not key in val:
                raise ValueError(_("Permissions must contain 'mode', 'owner', 'group' and 'label' keys."))
        self._perms = val


    # Validation helper functions
    def _validate_path(self, path):
        if type(path) is not type("str") or not path.startswith("/"):
            raise ValueError(_("'%s' is not an absolute path." % path))

    def _check_name_collision(self, name):
        raise RuntimeError, "Must be implemented in subclass"

    # XML Building
    def _get_storage_xml(self):
        """
        Returns the pool/volume specific xml blob
        """
        raise RuntimeError, "Must be implemented in subclass"

    def _get_perms_xml(self):
        perms = self.get_perms()
        if not perms:
            return ""
        return "    <permissions>\n" + \
               "      <mode>%o</mode>\n" % perms["mode"] + \
               "      <owner>%d</owner>\n" % perms["owner"] + \
               "      <group>%d</group>\n" % perms["group"] + \
               "      <label>%s</label>\n" % perms["label"] + \
               "    </permissions>\n"


    def get_xml_config(self):
        """
        Construct the xml description of the storage object

        @returns: xml description
        @rtype: C{str}
        """
        if self.type is None:
            root_xml = "<%s>\n" % self.object_type
        else:
            root_xml = "<%s type='%s'>\n" % (self.object_type, self.type)

        xml = "%s" % (root_xml) + \
              """  <name>%s</name>\n""" % (self.name) + \
              """%(stor_xml)s""" % { "stor_xml" : self._get_storage_xml() } + \
              """</%s>""" % (self.object_type)
        return xml




class StoragePool(StorageObject):
    """
    Base class for building and installing libvirt storage pool xml
    """

    TYPE_DIR     = "dir"
    TYPE_FS      = "fs"
    TYPE_NETFS   = "netfs"
    TYPE_LOGICAL = "logical"
    TYPE_DISK    = "disk"
    TYPE_ISCSI   = "iscsi"
    """@group Types: TYPE_*"""

    # Pool type descriptions for use in higher level programs
    _types = {}
    _types[TYPE_DIR]     = _("Filesystem Directory")
    _types[TYPE_FS]      = _("Pre-Formatted Block Device")
    _types[TYPE_NETFS]   = _("Network Exported Directory")
    _types[TYPE_LOGICAL] = _("LVM Volume Group")
    _types[TYPE_DISK]    = _("Physical Disk Device")
    _types[TYPE_ISCSI]   = _("iSCSI Target")

    def get_pool_class(ptype):
        """
        Return class associated with passed pool type.

        @param ptype: Pool type
        @type ptype: C{str} member of L{Types}
        """
        if ptype not in StoragePool._types:
            raise ValueError, _("Unknown storage pool type: %s" % ptype)
        if ptype == StoragePool.TYPE_DIR:
            return DirectoryPool
        if ptype == StoragePool.TYPE_FS:
            return FilesystemPool
        if ptype == StoragePool.TYPE_NETFS:
            return NetworkFilesystemPool
        if ptype == StoragePool.TYPE_LOGICAL:
            return LogicalPool
        if ptype == StoragePool.TYPE_DISK:
            return DiskPool
        if ptype == StoragePool.TYPE_ISCSI:
            return iSCSIPool
    get_pool_class = staticmethod(get_pool_class)

    def get_volume_for_pool(pool_type):
        """Convenience method, returns volume class associated with pool_type"""
        pool_class = StoragePool.get_pool_class(pool_type)
        return pool_class.get_volume_class()
    get_volume_for_pool = staticmethod(get_volume_for_pool)

    def get_pool_types():
        """Return list of appropriate pool types"""
        return StoragePool._types.keys()
    get_pool_types = staticmethod(get_pool_types)

    def get_pool_type_desc(pool_type):
        """Return human readable description for passed pool type"""
        return StoragePool._types[pool_type]
    get_pool_type_desc = staticmethod(get_pool_type_desc)


    def __init__(self, conn, name, type, target_path=None, uuid=None):
        StorageObject.__init__(self, object_type=StorageObject.TYPE_POOL, \
                               name=name, conn=conn)

        if type not in self.get_pool_types():
            raise ValueError, _("Unknown storage pool type: %s" % type)
        self._type = type
        if target_path is None:
            target_path = self._get_default_target_path()
        self.target_path = target_path

        # Initialize all optional properties
        self._host = None
        self._source_path = None
        if not uuid:
            self._uuid = None
        self._random_uuid = _util.uuidToString(_util.randomUUID())

    # Properties used by all pools
    def get_type(self):
        return self._type
    type = property(get_type)

    def get_target_path(self):
        return self._target_path
    def set_target_path(self, val):
        self._validate_path(val)
        self._target_path = val
    target_path = property(get_target_path, set_target_path)

    # Get/Set methods for use by some pools. Will be registered when applicable
    def get_source_path(self):
        return self._source_path
    def set_source_path(self, val):
        self._validate_path(val)
        self._source_path = val

    def get_host(self):
        return self._host
    def set_host(self, val):
        if type(val) is not type("str"):
            raise ValueError(_("Host name must be a string"))
        self._host = val

    """uuid: uuid of the storage object. optional: generated if not set"""
    def get_uuid(self):
        return self._uuid
    def set_uuid(self, val):
        if type(val) is not type("string"):
            raise ValueError, _("UUID must be a string.")

        form = re.match("[a-fA-F0-9]{8}[-]([a-fA-F0-9]{4}[-]){3}[a-fA-F0-9]{12}$", val)
        if form is None:
            form = re.match("[a-fA-F0-9]{32}$", val)
            if form is None:
                raise ValueError, _("UUID must be a 32-digit hexadecimal number. It may take the form XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX or may omit hyphens altogether.")

            else:   # UUID had no dashes, so add them in
                val=val[0:8] + "-" + val[8:12] + "-" + val[12:16] + \
                    "-" + val[16:20] + "-" + val[20:32]
        self._uuid = val
    uuid = property(get_uuid, set_uuid)

    # Validation functions
    def _check_name_collision(self, name):
        pool = None
        try:
            pool = self.conn.storagePoolLookupByName(name)
        except libvirt.libvirtError:
            pass
        if pool:
            raise ValueError(_("Name '%s' already in use by another pool." %
                                name))

    def _get_default_target_path(self):
        raise RuntimeError, "Must be implemented in subclass"

    # XML Building
    def _get_target_xml(self):
        raise RuntimeError, "Must be implemented in subclass"

    def _get_source_xml(self):
        raise RuntimeError, "Must be implemented in subclass"

    def _get_storage_xml(self):
        src_xml = ""
        if self._get_source_xml() != "":
            src_xml = "  <source>\n" + \
                      "%s" % (self._get_source_xml()) + \
                      "  </source>\n"
        tar_xml = "  <target>\n" + \
                  "%s" % (self._get_target_xml()) + \
                  "  </target>\n"

        return "  <uuid>%s</uuid>\n" % (self.uuid or self._random_uuid) + \
               "%s" % src_xml + \
               "%s" % tar_xml

    def install(self, meter=None, create=False, build=False):
        """
        Install storage pool xml.
        """
        xml = self.get_xml_config()
        logging.debug("Creating storage pool '%s' with xml:\n%s" % \
                      (self.name, xml))

        try:
            pool = self.conn.storagePoolDefineXML(xml, 0)
        except Exception, e:
            raise RuntimeError(_("Could not define storage pool: %s" % str(e)))

        errmsg = None
        if build:
            if meter:
                #meter.start(size=None, text=_("Creating storage pool..."))
                pass
            try:
                pool.build(libvirt.VIR_STORAGE_POOL_BUILD_NEW)
            except Exception, e:
                errmsg = _("Could not build storage pool: %s" % str(e))
            if meter:
                #meter.end(0)
                pass

        if create and not errmsg:
            try:
                pool.create(0)
            except Exception, e:
                errmsg = _("Could not start storage pool: %s" % str(e))

        if errmsg:
            # Try and clean up the leftover pool
            try:
                pool.undefine()
            except Exception, e:
                logging.debug("Error cleaning up pool after failure: " +
                              "%s" % str(e))
            raise RuntimeError(errmsg)

        return pool


class DirectoryPool(StoragePool):
    """
    Create a directory based storage pool
    """

    def get_volume_class():
        return FileVolume
    get_volume_class = staticmethod(get_volume_class)

    # Register applicable property methods from parent class
    perms = property(StorageObject.get_perms, StorageObject.set_perms)

    def __init__(self, conn, name, target_path=None, uuid=None, perms=None):
        StoragePool.__init__(self, name=name, type=StoragePool.TYPE_DIR,
                             target_path=target_path, uuid=uuid, conn=conn)
        if perms:
            self.perms = perms

    def _get_default_target_path(self):
        path = (DEFAULT_DIR_TARGET_BASE + self.name)
        return path

    def _get_target_xml(self):
        xml = "    <path>%s</path>\n" % escape(self.target_path) + \
              "%s" % self._get_perms_xml()
        return xml

    def _get_source_xml(self):
        return ""

class FilesystemPool(StoragePool):
    """
    Create a formatted partition based storage pool
    """

    def get_volume_class():
        return FileVolume
    get_volume_class = staticmethod(get_volume_class)

    formats = [ "auto", "ext2", "ext3", "ext4", "ufs", "iso9660", "udf",
                "gfs", "gfs2", "vfat", "hfs+", "xfs" ]

    # Register applicable property methods from parent class
    perms = property(StorageObject.get_perms, StorageObject.set_perms)
    source_path = property(StoragePool.get_source_path,
                           StoragePool.set_source_path)

    def __init__(self, conn, name, source_path=None, target_path=None,
                 format="auto", uuid=None, perms=None):
        StoragePool.__init__(self, name=name, type=StoragePool.TYPE_FS,
                             target_path=target_path, uuid=uuid, conn=conn)

        self.format = format

        if source_path:
            self.source_path = source_path
        if perms:
            self.perms = perms

    def get_format(self):
        return self._format
    def set_format(self, val):
        if not val in self.formats:
            raise ValueError(_("Unknown Filesystem format: %s" % val))
        self._format = val
    format = property(get_format, set_format)

    def _get_default_target_path(self):
        path = (DEFAULT_DIR_TARGET_BASE + self.name)
        return path

    def _get_target_xml(self):
        xml = "    <path>%s</path>\n" % escape(self.target_path) + \
              "%s" % self._get_perms_xml()
        return xml

    def _get_source_xml(self):
        if not self.source_path:
            raise RuntimeError(_("Device path is required"))
        xml = "    <format type='%s'/>\n" % self.format + \
              "    <device path='%s'/>\n" % escape(self.source_path)
        return xml

class NetworkFilesystemPool(StoragePool):
    """
    Create a network mounted filesystem storage pool
    """

    def get_volume_class():
        return FileVolume
    get_volume_class = staticmethod(get_volume_class)

    formats = [ "auto", "nfs" ]

    # Register applicable property methods from parent class
    source_path = property(StoragePool.get_source_path,
                           StoragePool.set_source_path)
    host = property(StoragePool.get_host, StoragePool.set_host)

    def __init__(self, conn, name, source_path=None, host=None,
                 target_path=None, format="auto", uuid=None):
        StoragePool.__init__(self, name=name, type=StoragePool.TYPE_NETFS,
                             uuid=uuid, target_path=target_path, conn=conn)

        self.format = format

        if source_path:
            self.source_path = source_path
        if host:
            self.host = host

    def get_format(self):
        return self._format
    def set_format(self, val):
        if not val in self.formats:
            raise ValueError(_("Unknown Network Filesystem format: %s" % val))
        self._format = val
    format = property(get_format, set_format)

    def _get_default_target_path(self):
        path = (DEFAULT_DIR_TARGET_BASE + self.name)
        return path

    def _get_target_xml(self):
        xml = "    <path>%s</path>\n" % escape(self.target_path)
        return xml

    def _get_source_xml(self):
        if not self.host:
            raise RuntimeError(_("Hostname is required"))
        if not self.source_path:
            raise RuntimeError(_("Host path is required"))
        xml = """    <format type="%s"/>\n""" % self.format + \
              """    <host name="%s"/>\n""" % self.host + \
              """    <dir path="%s"/>\n""" % escape(self.source_path)
        return xml

class LogicalPool(StoragePool):
    """
    Create a logical (lvm volume group) storage pool
    """
    def get_volume_class():
        return LogicalVolume
    get_volume_class = staticmethod(get_volume_class)

    # Register applicable property methods from parent class
    perms = property(StorageObject.get_perms, StorageObject.set_perms)

    def __init__(self, conn, name, target_path=None, uuid=None, perms=None):
        StoragePool.__init__(self, name=name, type=StoragePool.TYPE_LOGICAL,
                             target_path=target_path, uuid=uuid, conn=conn)
        if perms:
            self.perms = perms

    def _get_default_target_path(self):
        return DEFAULT_LVM_TARGET_BASE + self.name

    def _get_target_xml(self):
        xml = "    <path>%s</path>\n" % escape(self.target_path) + \
              "%s" % self._get_perms_xml()
        return xml

    def _get_source_xml(self):
        return ""

class DiskPool(StoragePool):
    """
    Create a storage pool from a physical disk
    """

    # Register applicable property methods from parent class
    source_path = property(StoragePool.get_source_path,
                           StoragePool.set_source_path)

    formats = [ "auto", "bsd", "dos", "dvh", "gpt", "mac", "pc98", "sun" ]

    def get_volume_class():
        raise NotImplementedError(_("Disk volume creation is not implemented."))
    get_volume_class = staticmethod(get_volume_class)

    def __init__(self, conn, name, source_path=None, target_path=None,
                 format="auto", uuid=None):
        StoragePool.__init__(self, name=name, type=StoragePool.TYPE_DISK,
                             uuid=uuid, target_path=target_path, conn=conn)
        self.format = format
        if source_path:
            self.source_path = source_path

    def get_format(self):
        return self._format
    def set_format(self, val):
        if not val in self.formats:
            raise ValueError(_("Unknown Disk format: %s" % val))
        self._format = val
    format = property(get_format, set_format)

    def _get_default_target_path(self):
        return DEFAULT_DEV_TARGET

    def _get_target_xml(self):
        xml = "   <path>%s</path>\n" % escape(self.target_path)
        return xml

    def _get_source_xml(self):
        if not self.source_path:
            raise RuntimeError(_("Host path is required"))

        xml = ""
        # There is no explicit "auto" type for disk pools, but leaving out
        # the format type seems to do the job for existing formatted disks
        if self.format != "auto":
            xml = """    <format type="%s"/>\n""" % self.format
        xml += """    <device path="%s"/>\n""" % escape(self.source_path)
        return xml

    def install(self, meter=None, create=False, build=False):
        if self.format == "auto" and build:
            raise ValueError(_("Must explicitly specify disk format if "
                               "formatting disk device."))
        return StoragePool.install(self, meter=meter, create=create,
                                   build=build)

class iSCSIPool(StoragePool):
    """
    Create an iSCSI based storage pool
    """

    host = property(StoragePool.get_host, StoragePool.set_host)

    def get_volume_class():
        raise NotImplementedError(_("iSCSI volume creation is not "
                                    "implemented."))
    get_volume_class = staticmethod(get_volume_class)

    def __init__(self, conn, name, source_path=None, host=None,
                 target_path=None, uuid=None):
        StoragePool.__init__(self, name=name, type=StoragePool.TYPE_ISCSI,
                             uuid=uuid, target_path=target_path, conn=conn)

        if source_path:
            self.source_path = source_path
        if host:
            self.host = host

    # Need to overwrite pool *_source_path since iscsi device isn't
    # a fully qualified path
    def get_source_path(self):
        return self._source_path
    def set_source_path(self, val):
        self._source_path = val
    source_path = property(get_source_path, set_source_path)

    def _get_default_target_path(self):
        return DEFAULT_ISCSI_TARGET

    def _get_target_xml(self):
        xml = "    <path>%s</path>\n" % escape(self.target_path)
        return xml

    def _get_source_xml(self):
        if not self.host:
            raise RuntimeError(_("Hostname is required"))
        if not self.source_path:
            raise RuntimeError(_("Host path is required"))
        xml = """    <host name="%s"/>\n""" % self.host + \
              """    <device path="%s"/>\n""" % escape(self.source_path)
        return xml

class StorageVolume(StorageObject):
    """
    Base class for building and installing libvirt storage volume xml
    """

    formats = []

    def __init__(self, name, capacity, conn=None, pool_name=None, pool=None,
                 allocation=0):
        if pool is None:
            if pool_name is None:
                raise ValueError(_("One of pool or pool_name must be "
                                   "specified."))
            if conn is None:
                raise ValueError(_("'conn' must be specified with 'pool_name'"))
            pool = StorageVolume.lookup_pool_by_name(pool_name=pool_name,
                                                     conn=conn)
        self.pool = pool

        StorageObject.__init__(self, object_type=StorageObject.TYPE_VOLUME,
                               name=name, conn=self.pool._conn)
        self._allocation = None
        self._capacity = None
        self.allocation = allocation
        self.capacity = capacity

    def get_volume_for_pool(pool_object=None, pool_name=None, conn=None):
        """
        Returns volume class associated with passed pool_object/name
        """
        pool_object = StorageVolume.lookup_pool_by_name(pool_object=pool_object,
                                                        pool_name=pool_name,
                                                        conn=conn)
        return StoragePool.get_volume_for_pool(_util.get_xml_path(pool_object.XMLDesc(0), "/pool/@type"))
    get_volume_for_pool = staticmethod(get_volume_for_pool)

    def find_free_name(name, pool_object=None, pool_name=None, conn=None,
                       suffix=""):
        """
        Finds a name similar (or equal) to passed 'name' that is not in use
        by another pool

        This function scans the list of existing Volumes on the passed or
        looked up pool object for a collision with the passed name. If the
        name is in use, it append "-1" to the name and tries again, then "-2",
        continuing to 100000 (which will hopefully never be reached.") If
        suffix is specified, attach it to the (potentially incremented) name
        before checking for collision.

        Ex name="test", suffix=".img" -> name-3.img

        @returns: A free name
        @rtype: C{str}
        """

        pool_object = StorageVolume.lookup_pool_by_name(pool_object=pool_object,
                                                        pool_name=pool_name,
                                                        conn=conn)
        pool_object.refresh(0)

        for i in range(0, 100000):
            tryname = name
            if i != 0:
                tryname += ("-%d" % i)
            tryname += suffix
            try:
                pool_object.storageVolLookupByName(tryname)
            except libvirt.libvirtError:
                return tryname
        raise ValueError(_("Default volume target path range exceeded."))
    find_free_name = staticmethod(find_free_name)

    def lookup_pool_by_name(pool_object=None, pool_name=None, conn=None):
        """
        Returns pool object determined from passed parameters.

        Largely a convenience function for the other static functions.
        """
        if pool_object is None and pool_name is None:
            raise ValueError(_("Must specify pool_object or pool_name"))

        if pool_name is not None and pool_object is None:
            if conn is None:
                raise ValueError(_("'conn' must be specified with 'pool_name'"))
            if not _util.is_storage_capable(conn):
                raise ValueError(_("Connection does not support storage "
                                   "management."))
            try:
                pool_object = conn.storagePoolLookupByName(pool_name)
            except Exception, e:
                raise ValueError(_("Couldn't find storage pool '%s': %s" % \
                                   (pool_name, str(e))))

        if not isinstance(pool_object, libvirt.virStoragePool):
            raise ValueError(_("pool_object must be a virStoragePool"))

        return pool_object
    lookup_pool_by_name = staticmethod(lookup_pool_by_name)


    def get_type(self):
        return None
    type = property(get_type)

    # Properties used by all volumes
    def get_capacity(self):
        return self._capacity
    def set_capacity(self, val):
        if type(val) not in (int, float, long) or val <= 0:
            raise ValueError(_("Capacity must be a positive number"))
        newcap = int(val)
        origcap = self.capacity
        origall = self.allocation
        self._capacity = newcap
        if self.allocation != None and (newcap < self.allocation):
            self._allocation = newcap

        ret = self.is_size_conflict()
        if ret[0]:
            self._capacity = origcap
            self._allocation = origall
            raise ValueError(ret[1])
        elif ret[1]:
            logging.warn(ret[1])
    capacity = property(get_capacity, set_capacity)

    def get_allocation(self):
        return self._allocation
    def set_allocation(self, val):
        if type(val) not in (int, float, long) or val < 0:
            raise ValueError(_("Allocation must be a non-negative number"))
        newall = int(val)
        if self.capacity != None and newall > self.capacity:
            logging.debug("Capping allocation at capacity.")
            newall = self.capacity
        origall = self._allocation
        self._allocation = newall

        ret = self.is_size_conflict()
        if ret[0]:
            self._allocation = origall
            raise ValueError(ret[1])
        elif ret[1]:
            logging.warn(ret[1])
    allocation = property(get_allocation, set_allocation)

    def get_pool(self):
        return self._pool
    def set_pool(self, newpool):
        if not isinstance(newpool, libvirt.virStoragePool):
            raise ValueError, _("'pool' must be a virStoragePool instance.")
        if newpool.info()[0] != libvirt.VIR_STORAGE_POOL_RUNNING:
            raise ValueError, _("pool '%s' must be active." % newpool.name())
        self._pool = newpool
    pool = property(get_pool, set_pool)

    # Property functions used by more than one child class
    def get_format(self):
        return self._format
    def set_format(self, val):
        if val not in self.formats:
            raise ValueError(_("'%s' is not a valid format.") % val)
        self._format = val

    def _check_name_collision(self, name):
        vol = None
        try:
            vol = self.pool.storageVolLookupByName(name)
        except libvirt.libvirtError:
            pass
        if vol:
            raise ValueError(_("Name '%s' already in use by another volume." %
                                name))

    def _check_target_collision(self, path):
        col = None
        try:
            col = self.conn.storageVolLookupByPath(path)
        except libvirt.libvirtError:
            pass
        if col:
            return True
        return False

    # xml building functions
    def _get_target_xml(self):
        raise RuntimeError, "Must be implemented in subclass"

    def _get_source_xml(self):
        raise RuntimeError, "Must be implemented in subclass"

    def _get_storage_xml(self):
        src_xml = ""
        if self._get_source_xml() != "":
            src_xml = "  <source>\n" + \
                      "%s" % (self._get_source_xml()) + \
                      "  </source>\n"
        tar_xml = "  <target>\n" + \
                  "%s" % (self._get_target_xml()) + \
                  "  </target>\n"
        return  "  <capacity>%d</capacity>\n" % self.capacity + \
                "  <allocation>%d</allocation>\n" % self.allocation + \
                "%s" % src_xml + \
                "%s" % tar_xml

    def install(self, meter=None):
        """
        Build and install storage volume from xml
        """
        xml = self.get_xml_config()
        logging.debug("Creating storage volume '%s' with xml:\n%s" % \
                      (self.name, xml))
        if meter:
            #meter.start(size=self.capacity,
            #            text=_("Creating storage volume..."))
            # XXX: We don't have any meaningful way to update the meter
            # XXX: throughout the operation, so just skip it
            pass
        try:
            vol = self.pool.createXML(xml, 0)
        except Exception, e:
            raise RuntimeError("Couldn't create storage volume '%s': '%s'" %
                               (self.name, str(e)))
        if meter:
            #meter.end(0)
            pass
        logging.debug("Storage volume '%s' install complete." % self.name)
        return vol

    def is_size_conflict(self):
        """
        Report if requested size exceeds its pool's available amount

        @returns: 2 element tuple:
            1. True if collision is fatal, false otherwise
            2. String message if some collision was encountered.
        @rtype: 2 element C{tuple}: (C{bool}, C{str})
        """
        # pool info is [ pool state, capacity, allocation, available ]
        avail = self.pool.info()[3]
        if self.allocation > avail:
            return (True, _("There is not enough free space on the storage "
                            "pool to create the volume. "
                            "(%d M requested allocation > %d M available)" % \
                            ((self.allocation/(1024*1024)),
                             (avail/(1024*1024)))))
        elif self.capacity > avail:
            return (False, _("The requested volume capacity will exceed the "
                             "available pool space when the volume is fully "
                             "allocated. "
                             "(%d M requested capacity > %d M available)" % \
                             ((self.capacity/(1024*1024)),
                              (avail/(1024*1024)))))
        return (False, "")

class FileVolume(StorageVolume):
    """
    Build and install xml for use on pools which use file based storage
    """

    formats = ["raw", "bochs", "cloop", "cow", "dmg", "iso", "qcow",\
               "qcow2", "vmdk", "vpc"]

    # Register applicable property methods from parent class
    perms = property(StorageObject.get_perms, StorageObject.set_perms)
    format = property(StorageVolume.get_format, StorageVolume.set_format)

    def __init__(self, name, capacity, pool=None, pool_name=None, conn=None,
                 format="raw", allocation=None, perms=None):
        StorageVolume.__init__(self, name=name, pool=pool, pool_name=pool_name,
                               allocation=allocation, capacity=capacity,
                               conn=conn)
        self.format = format
        if perms:
            self.perms = perms

    def _get_target_xml(self):
        return "    <format type='%s'/>\n" % self.format + \
               "%s" % self._get_perms_xml()

    def _get_source_xml(self):
        return ""

#class DiskVolume(StorageVolume):
#    """
#    Build and install xml for use on disk device pools
#    """
#    def __init__(self, *args, **kwargs):
#        raise NotImplementedError

#class iSCSIVolume(StorageVolume):
#    """
#    Build and install xml for use on iSCSI device pools
#    """
#    def __init__(self, *args, **kwargs):
#        raise NotImplementedError

class LogicalVolume(StorageVolume):
    """
    Build and install logical volumes for lvm pools
    """

    # Register applicable property methods from parent class
    perms = property(StorageObject.get_perms, StorageObject.set_perms)

    def __init__(self, name, capacity, pool=None, pool_name=None, conn=None,
                 allocation=None, perms=None):
        StorageVolume.__init__(self, name=name, pool=pool, pool_name=pool_name,
                               allocation=allocation, capacity=capacity,
                               conn=conn)
        if perms:
            self.perms = perms

    def _get_target_xml(self):
        return "%s" % self._get_perms_xml()

    def _get_source_xml(self):
        return ""
