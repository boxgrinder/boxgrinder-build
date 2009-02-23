#
# Copyright(c) FUJITSU Limited 2007.
#
# Cloning a virtual machine module.
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
Module for cloning an existing virtual machine

General workflow for cloning:

    - Instantiate CloneDesign. Requires at least a libvirt connection and
      a name of a domain to clone.

    - Run 'setup' from the CloneDesign instance to prep for cloning

    - Run 'CloneManager.start_duplicate', passing the CloneDesign instance
"""

import os
import libxml2
import logging
import subprocess
import _util
import libvirt
import Guest
from VirtualDisk import VirtualDisk
from virtinst import _virtinst as _

#
# This class is the design paper for a clone virtual machine.
#
class CloneDesign(object):

    def __init__(self, connection):
        # hypervisor connection
        self._hyper_conn = connection

        # original guest name or uuid
        self._original_guest        = None
        self._original_dom          = None
        self._original_devices      = []
        self._original_devices_size = []
        self._original_devices_type = []
        self._original_xml          = None

        # Deliberately private: user doesn't need to know this
        self._original_devices_idx = []

        # clone guest
        self._clone_name         = None
        self._clone_devices      = []
        self._clone_devices_size = []
        self._clone_devices_type = []
        self._clone_bs           = 1024*1024*10
        self._clone_mac          = []
        self._clone_uuid         = None
        self._clone_sparse       = True
        self._clone_xml          = None

        self._force_target       = []

        self._preserve           = True

        # Throwaway guest to use for easy validation
        self._valid_guest        = Guest.Guest(connection=connection)


    # Getter/Setter methods

    def get_original_guest(self):
        return self._original_guest
    def set_original_guest(self, original_guest):
        if type(original_guest) is not type("str") or len(original_guest)==0:
            raise ValueError, _("Name or UUID of guest to clone is required")

        try:
            self._valid_guest.set_uuid(original_guest)
        except ValueError:
            try:
                self._valid_guest.set_name(original_guest)
            except ValueError:
                raise ValueError, \
                    _("A valid name or UUID of guest to clone is required")
        self._original_guest = original_guest
    original_guest = property(get_original_guest, set_original_guest)

    def get_clone_name(self):
        return self._clone_name
    def set_clone_name(self, name):
        try:
            self._valid_guest.set_name(name)
        except ValueError, e:
            raise ValueError, _("Invalid name for new guest: %s") % (str(e),)
        self._clone_name = name
    clone_name = property(get_clone_name, set_clone_name)

    def set_clone_uuid(self, uuid):
        try:
            self._valid_guest.set_uuid(uuid)
        except ValueError, e:
            raise ValueError, _("Invalid uuid for new guest: %s") % (str(e),)
        self._clone_uuid = uuid
    def get_clone_uuid(self):
        return self._clone_uuid
    clone_uuid = property(get_clone_uuid, set_clone_uuid)

    def set_clone_devices(self, devices):
        # Devices here is a string path. Every call to set_clone_devices
        # Adds the path (if valid) to the internal _clone_devices list
        if len(devices) == 0:
            raise ValueError, _("New file to use for disk image is required")

        # Check path's size (if present)
        # XXX: Only works locally
        cdev_size, dummy = self._local_paths_info([devices])

        # Make sure path is valid and we can use it
        devices = self._check_file(self._hyper_conn, devices, cdev_size[0])
        self._clone_devices.append(devices)
    def get_clone_devices(self):
        return self._clone_devices
    clone_devices = property(get_clone_devices, set_clone_devices)

    def set_clone_mac(self, mac):
        Guest.VirtualNetworkInterface(mac, conn=self.original_conn)
        self._clone_mac.append(mac)
    def get_clone_mac(self):
        return self._clone_mac
    clone_mac = property(get_clone_mac, set_clone_mac)

    def get_clone_bs(self):
        return self._clone_bs
    def set_clone_bs(self, rate):
        self._clone_bs = rate
    clone_bs = property(get_clone_bs, set_clone_bs)

    def get_original_devices_size(self):
        return self._original_devices_size
    original_devices_size = property(get_original_devices_size)

    def get_original_devices(self):
        return self._original_devices
    original_devices = property(get_original_devices)

    def get_hyper_conn(self):
        return self._hyper_conn
    original_conn = property(get_hyper_conn)

    def get_original_dom(self):
        return self._original_dom
    original_dom = property(get_original_dom)

    def get_original_xml(self):
        return self._original_xml
    original_xml = property(get_original_xml)

    def get_clone_xml(self):
        return self._clone_xml
    def set_clone_xml(self, clone_xml):
        self._clone_xml = clone_xml
    clone_xml = property(get_clone_xml, set_clone_xml)

    def get_clone_sparse(self):
        return self._clone_sparse
    def set_clone_sparse(self, flg):
        self._clone_sparse = flg
    clone_sparse = property(get_clone_sparse, set_clone_sparse)

    def get_preserve(self):
        return self._preserve
    def set_preserve(self, flg):
        self._preserve = flg
    preserve = property(get_preserve, set_preserve)

    def set_force_target(self, dev):
        self._force_target.append(dev)
    def get_force_target(self):
        return self._force_target
    force_target = property(set_force_target)


    # Functional methods

    def setup_original(self):
        """
        Validate and setup all parameters needed for the original (cloned) VM
        """
        logging.debug("Validating original guest parameters")

        try:
            self._original_dom = self._hyper_conn.lookupByName(self._original_guest)
        except libvirt.libvirtError:
            raise RuntimeError, _("Domain %s is not found") % self._original_guest

        # For now, clone_xml is just a copy of the original
        self._original_xml = self._original_dom.XMLDesc(0)
        self._clone_xml    = self._original_dom.XMLDesc(0)

        # Pull clonable storage info from the original xml
        self._original_devices,     \
        self._original_devices_size,\
        self._original_devices_type,\
        self._original_devices_idx = self._get_original_devices_info(self._original_xml)

        logging.debug("Original paths: %s" % (self._original_devices))
        logging.debug("Original sizes: %s" % (self._original_devices_size))
        logging.debug("Original types: %s" % (self._original_devices_type))
        logging.debug("Original idxs: %s" % (self._original_devices_idx))

        # Check original domain is SHUTOFF
        # XXX: Shouldn't pause also be fine, and guests with no storage/
        # XXX: readonly + sharable storage can be cloned while running
        status = self._original_dom.info()[0]
        logging.debug("original guest status: %s" % (status))
        if status != libvirt.VIR_DOMAIN_SHUTOFF:
            raise RuntimeError, _("Domain status must be SHUTOFF")

        # Make sure new VM name isn't taken.
        # XXX: Check this at set time?
        try:
            if self._hyper_conn.lookupByName(self._clone_name) is not None:
                raise RuntimeError, _("Domain %s already exists") % self._clone_name
        except libvirt.libvirtError:
            pass

        # Check specified UUID isn't taken
        if _util.vm_uuid_collision(self._hyper_conn, self._clone_uuid):
            raise RuntimeError, _("The UUID you entered is already in use by "
                                  "another guest!")

        # Check mac address is not in use
        # XXX: Check this at set time?
        for i in self._clone_mac:
            ret, msg = self._check_mac(i)
            if msg is not None:
                if ret:
                    raise RuntimeError, msg
                else:
                    logging.warning(msg)


    def setup_clone(self):
        """
        Validate and set up all parameters needed for the new (clone) VM
        """
        logging.debug("Validating clone parameters.")

        # XXX: Make sure a clone name has been specified? or generate one?

        # XXX: Only works locally
        self._clone_devices_size,\
        self._clone_devices_type = self._local_paths_info(self._clone_devices)

        logging.debug("Clone paths: %s" % (self._clone_devices))
        logging.debug("Clone sizes: %s" % (self._clone_devices_size))
        logging.debug("Clone types: %s" % (self._clone_devices_type))

        # We simply edit the original VM xml in place
        # XXX: Does this need a huge try except so we don't leak xml memory
        # XXX: on failure?
        doc = libxml2.parseDoc(self._clone_xml)
        ctx = doc.xpathNewContext()
        typ = ctx.xpathEval("/domain")[0].prop("type")

        # changing name
        node = ctx.xpathEval("/domain/name")
        node[0].setContent(self._clone_name)

        # Changing storage paths
        clone_devices = iter(self._clone_devices)
        for i in self._original_devices_idx:
            node = ctx.xpathEval("/domain/devices/disk[%d]/source" % i)
            node = node[0].get_properties()
            try:
                node.setContent(clone_devices.next())
            except Exception:
                raise ValueError, _("Missing new file to use disk image "
                                    "for %s") % node.getContent()

        # changing uuid
        node = ctx.xpathEval("/domain/uuid")
        if self._clone_uuid is not None:
            node[0].setContent(self._clone_uuid)
        else:
            while 1:
                uuid = _util.uuidToString(_util.randomUUID())
                if _util.vm_uuid_collision(self._hyper_conn, uuid):
                    continue
                break
            node[0].setContent(uuid)

        # changing mac
        count = ctx.xpathEval("count(/domain/devices/interface/mac)")
        for i in range(1, int(count+1)):
            node = ctx.xpathEval("/domain/devices/interface[%d]/mac/@address" % i)
            try:
                node[0].setContent(self._clone_mac[i-1])
            except Exception:
                while 1:
                    mac = _util.randomMAC(typ)
                    dummy, msg = self._check_mac(mac)
                    if msg is not None:
                        continue
                    else:
                        break
                node[0].setContent(mac)

        # Change xml disk type values if original and clone disk types
        # (block/file) don't match
        self._change_disk_type(self._original_devices_type,
                               self._clone_devices_type,
                               self._original_devices_idx,
                               ctx)

        # Save altered clone xml
        self._clone_xml = str(doc)

        ctx.xpathFreeContext()
        doc.freeDoc()


    def setup(self):
        """
        Helper function that wraps setup_original and setup_clone, with
        additional debug logging.
        """
        self.setup_original()
        logging.debug("Original guest xml is\n%s" % (self._original_xml))

        self.setup_clone()
        logging.debug("Clone guest xml is\n%s" % (self._clone_xml))


    # Private helper functions

    # Check if new file path is valid
    def _check_file(self, conn, disk, size):
        d = VirtualDisk(disk, size, conn=conn)
        return d.path

    # Check if new mac address is valid
    def _check_mac(self, mac):
        nic = Guest.VirtualNetworkInterface(macaddr=mac,
                                            conn=self.original_conn)
        return nic.is_conflict_net(self._hyper_conn)

    # Parse disk paths that need to be cloned from the original guest's xml
    # Return a tuple of lists:
    # ([list of paths to clone], [size of those paths],
    #  [file/block type of those paths], [indices of disks to be cloned])
    def _get_original_devices_info(self, xml):

        lst  = []
        size = []
        typ  = []
        idx_lst = []

        doc = libxml2.parseDoc(xml)
        ctx = doc.xpathNewContext()
        try:
            count = ctx.xpathEval("count(/domain/devices/disk)")
            for i in range(1, int(count+1)):
                # Check if the disk needs cloning
                node = self._get_available_cloning_device(ctx, i, self._force_target)
                if node == None:
                    continue
                idx_lst.append(i)
                lst.append(node[0].get_properties().getContent())
        finally:
            if ctx is not None:
                ctx.xpathFreeContext()
            if doc is not None:
                doc.freeDoc()

        # Lookup size and storage type (file/block)
        for i in lst:
            (t, sz) = _util.stat_disk(i)
            typ.append(t)
            size.append(sz)

        return (lst, size, typ, idx_lst)

    # Pull disk #i from the original guest xml, return it's xml
    # if it should be cloned (skips readonly, empty, or sharable disks
    # unless its target is in the 'force' list)
    def _get_available_cloning_device(self, ctx, i, force):

        node = None
        force_flg = False

        node = ctx.xpathEval("/domain/devices/disk[%d]/source" % i)
        # If there is no media path, ignore
        if len(node) == 0:
            return None

        target = ctx.xpathEval("/domain/devices/disk[%d]/target/@dev" % i)
        target = target[0].getContent()

        for f_target in force:
            if target == f_target:
                force_flg = True

        # Skip readonly disks unless forced
        ro = ctx.xpathEval("/domain/devices/disk[%d]/readonly" % i)
        if len(ro) != 0 and force_flg == False:
            return None
        # Skip sharable disks unless forced
        share = ctx.xpathEval("/domain/devices/disk[%d]/shareable" % i) 
        if len(share) != 0 and force_flg == False:
            return None

        return node

    # Stat each path in the passed list, return a tuple of
    # ([size of each path (0 if non-existent)],
    #  [file/block type of each path (true for 'file', false for 'block')]
    def _local_paths_info(self, paths_lst):

        size = []
        typ  = []

        for i in paths_lst:
            (t, sz) = _util.stat_disk(i)
            typ.append(t)
            size.append(sz)

        return (size, typ)

    # Check if original disk type (file/block) is different from
    # requested clones disk type, and alter xml if needed
    def _change_disk_type(self, org_type, cln_type, idxs, ctx):

        type_idx = 0
        for dev_idx in idxs:
            disk_type = ctx.xpathEval("/domain/devices/disk[%d]/@type" %
                                      dev_idx)
            driv_name = ctx.xpathEval("/domain/devices/disk[%d]/driver/@name" % dev_idx)
            src = ctx.xpathEval("/domain/devices/disk[%d]/source" % dev_idx)
            src_chid_txt = src[0].get_properties().getContent()

            # different type
            if org_type[type_idx] != cln_type[type_idx]:
                if org_type[type_idx] == True:
                    # changing from file to disk
                    typ, driv, newprop = ("block", "phy", "dev")
                else:
                    # changing from disk to file
                    typ, driv, newprop = ("file", "file", "file")

                disk_type[0].setContent(typ)
                if driv_name:
                    driv_name[0].setContent(driv)
                src[0].get_properties().unlinkNode()
                src[0].newProp(newprop, src_chid_txt)

            type_idx += 1

#
# start duplicate
# this function clones the virtual machine according to the ClonDesign object
#
def start_duplicate(design, meter=None):

    logging.debug("start_duplicate in")

    # do dupulicate
    # at this point, handling the cloning way.
    if design.preserve == True:
        _do_duplicate(design, meter)

    # define clone xml
    design.original_conn.defineXML(design.clone_xml)

    logging.debug("start_duplicate out")

def _vdisk_clone(path, clone):
    path = os.path.expanduser(path)
    clone = os.path.expanduser(clone)
    try:
        rc = subprocess.call([ '/usr/sbin/vdiskadm', 'clone', path, clone ])
        return rc == 0
    except OSError:
        return False

#
# Now this Cloning method is reading and writing devices.
# For future, there are many cloning methods (e.g. fork snapshot cmd).
#
def _do_duplicate(design, meter):

    src_fd = None
    dst_fd = None
    dst_dev_iter = iter(design.clone_devices)
    dst_siz_iter = iter(design.original_devices_size)

    zeros            = '\0' * 4096
    sparse_copy_mode = False

    try:
        for src_dev in design.original_devices:
            dst_dev = dst_dev_iter.next()
            dst_siz = dst_siz_iter.next()

            meter.start(size=dst_siz,
                        text=_("Cloning from %(src)s to %(dst)s...") % \
                        {'src' : src_dev, 'dst' : dst_dev})

            if src_dev == "/dev/null" or src_dev == dst_dev:
                meter.end(dst_siz)
                continue

            # vdisk specific handlings
            if _util.is_vdisk(src_dev) or (os.path.exists(dst_dev) and
                                           _util.is_vdisk(dst_dev)):
                if not _util.is_vdisk(src_dev) or os.path.exists(dst_dev):
                    raise RuntimeError, _("copying to an existing vdisk is not supported")
                if not _vdisk_clone(src_dev, dst_dev):
                    raise RuntimeError, _("failed to clone disk")
                meter.end(dst_siz)
                continue

            #
            # create sparse file
            # if a destination file exists and sparse flg is True,
            # this priority takes a existing file.
            #
            if os.path.exists(dst_dev) == False and design.clone_sparse == True:
                design.clone_bs = 4096
                sparse_copy_mode = True
                fd = os.open(dst_dev, os.O_WRONLY | os.O_CREAT)
                os.ftruncate(fd, dst_siz)
                os.close(fd)
            else:
                design.clone_bs = 1024*1024*10
                sparse_copy_mode = False
            logging.debug("dst_dev:%s sparse_copy_mode:%s bs:%d" % (dst_dev,sparse_copy_mode,design.clone_bs))

            src_fd = os.open(src_dev, os.O_RDONLY)
            dst_fd = os.open(dst_dev, os.O_WRONLY | os.O_CREAT)

            i=0
            while 1:
                l = os.read(src_fd, design.clone_bs)
                s = len(l)
                if s == 0:
                    meter.end(dst_siz)
                    break
                # check sequence of zeros
                if sparse_copy_mode == True and zeros == l:
                    os.lseek(dst_fd, s, 1)
                else:
                    b = os.write(dst_fd, l)
                    if s != b:
                        meter.end(i)
                        break
                i += s
                if i < dst_siz:
                    meter.update(i)

            os.close(src_fd)
            src_fd = None
            os.close(dst_fd)
            dst_fd = None
    finally:
        if src_fd is not None:
            os.close(src_fd)
        if dst_fd is not None:
            os.close(dst_fd)

