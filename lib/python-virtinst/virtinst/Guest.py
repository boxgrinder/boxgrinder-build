#
# Common code for all guests
#
# Copyright 2006-2007  Red Hat, Inc.
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

import os, os.path
import errno
import struct
import time
import re
import libxml2
import urlgrabber.progress as progress
import _util
import libvirt
import platform
import __builtin__
import CapabilitiesParser
import VirtualDevice

import osdict
from VirtualDisk import VirtualDisk
from virtinst import _virtinst as _

import logging

XEN_SCRATCH="/var/lib/xen"
LIBVIRT_SCRATCH="/var/lib/libvirt/boot"

class VirtualNetworkInterface(VirtualDevice.VirtualDevice):

    TYPE_BRIDGE  = "bridge"
    TYPE_VIRTUAL = "network"
    TYPE_USER    = "user"

    def __init__(self, macaddr=None, type=TYPE_BRIDGE, bridge=None,
                 network=None, model=None, conn=None):
        VirtualDevice.VirtualDevice.__init__(self, conn)

        if macaddr is not None and \
           __builtin__.type(macaddr) is not __builtin__.type("string"):
            raise ValueError, "MAC address must be a string."

        if macaddr is not None:
            form = re.match("^([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2}$",macaddr)
            if form is None:
                raise ValueError, \
                    _("MAC address must be of the format AA:BB:CC:DD:EE:FF")
        self.macaddr = macaddr
        self.type = type
        self.bridge = bridge
        self.network = network
        self.model = model
        if self.type == self.TYPE_VIRTUAL:
            if network is None:
                raise ValueError, _("A network name was not provided")
        elif self.type == self.TYPE_BRIDGE:
            pass
        elif self.type == self.TYPE_USER:
            pass
        else:
            raise ValueError, _("Unknown network type %s") % (type,)

    def get_network(self):
        return self._network
    def set_network(self, newnet):
        def _is_net_active(netobj):
            """Apparently the 'info' command was never hooked up for
               libvirt virNetwork python apis."""
            if not self.conn:
                return True
            return self.conn.listNetworks().count(netobj.name())

        if newnet is not None and self.conn:
            try:
                net = self.conn.networkLookupByName(newnet)
            except libvirt.libvirtError, e:
                raise ValueError(_("Virtual network '%s' does not exist: %s") \
                                   % (newnet, str(e)))
            if not _is_net_active(net):
                raise ValueError(_("Virtual network '%s' has not been "
                                   "started.") % newnet)

        self._network = newnet
    network = property(get_network, set_network)

    def is_conflict_net(self, conn):
        """is_conflict_net: determines if mac conflicts with others in system

           returns a two element tuple:
               first element is True if fatal collision occured
               second element is a string description of the collision.
           Non fatal collisions (mac addr collides with inactive guest) will
           return (False, "description of collision")"""
        if self.macaddr is None:
            return (False, None)
        # get Running Domains
        ids = conn.listDomainsID()
        vms = []
        for i in ids:
            try:
                vm = conn.lookupByID(i)
                vms.append(vm)
            except libvirt.libvirtError:
                # guest probably in process of dieing
                logging.warn("conflict_net: Failed to lookup domain id %d" % i)
        # get inactive Domains
        inactive_vm = []
        names = conn.listDefinedDomains()
        for name in names:
            try:
                vm = conn.lookupByName(name)
                inactive_vm.append(vm)
            except:
                # guest probably in process of dieing
                logging.warn("conflict_net: Failed to lookup domain %d" % name)

        # get the Host's NIC MACaddress
        hostdevs = _util.get_host_network_devices()

        if self.countMACaddr(vms) > 0:
            return (True, _("The MAC address you entered is already in use by another active virtual machine."))
        for (dummy, dummy, dummy, dummy, host_macaddr) in hostdevs:
            if self.macaddr.upper() == host_macaddr.upper():
                return (True, _("The MAC address you entered conflicts with a device on the physical host."))
        if self.countMACaddr(inactive_vm) > 0:
            return (False, _("The MAC address you entered is already in use by another inactive virtual machine."))
        return (False, None)

    def setup(self, conn):
        if self.macaddr is None:
            while 1:
                self.macaddr = _util.randomMAC(type=conn.getType().lower())
                if self.is_conflict_net(conn)[1] is not None:
                    continue
                else:
                    break
        else:
            ret, msg = self.is_conflict_net(conn)
            if msg is not None:
                if ret is False:
                    logging.warning(msg)
                else:
                    raise RuntimeError(msg)

        if not self.bridge and self.type == "bridge":
            self.bridge = _util.default_bridge()

    def get_xml_config(self):
        src_xml = ""
        model_xml = ""
        if self.type == self.TYPE_BRIDGE:
            src_xml =   "      <source bridge='%s'/>\n" % self.bridge
        elif self.type == self.TYPE_VIRTUAL:
            src_xml =   "      <source network='%s'/>\n" % self.network

        if self.model:
            model_xml = "      <model type='%s'/>\n" % self.model

        return "    <interface type='%s'>\n" % self.type + \
               src_xml + \
               "      <mac address='%s'/>\n" % self.macaddr + \
               model_xml + \
               "    </interface>"

    def countMACaddr(self, vms):
        if not self.macaddr:
            return
        count = 0
        for vm in vms:
            doc = None
            try:
                doc = libxml2.parseDoc(vm.XMLDesc(0))
            except:
                continue
            ctx = doc.xpathNewContext()
            try:
                for mac in ctx.xpathEval("/domain/devices/interface/mac"):
                    macaddr = mac.xpathEval("attribute::address")[0].content
                    if macaddr and _util.compareMAC(self.macaddr, macaddr) == 0:
                        count += 1
            finally:
                if ctx is not None:
                    ctx.xpathFreeContext()
                if doc is not None:
                    doc.freeDoc()
        return count

class VirtualAudio(object):

    MODELS = [ "es1370", "sb16", "pcspk" ]

    def __init__(self, model):
        self.model = model

    def get_model(self):
        return self._model
    def set_model(self, new_model):
        if type(new_model) != str:
            raise ValueError, _("'model' must be a string, "
                                " was '%s'." % type(new_model))
        if not self.MODELS.count(new_model):
            raise ValueError, _("Unsupported sound model '%s'" % new_model)
        self._model = new_model
    model = property(get_model, set_model)

    def get_xml_config(self):
        return "    <sound model='%s'/>" % self.model

# Back compat class to avoid ABI break
class XenNetworkInterface(VirtualNetworkInterface):
    pass

class VirtualGraphics(object):

    TYPE_SDL = "sdl"
    TYPE_VNC = "vnc"

    def __init__(self, type=TYPE_VNC, port=-1, listen=None, passwd=None,
                 keymap=None):

        if type != self.TYPE_VNC and type != self.TYPE_SDL:
            raise ValueError(_("Unknown graphics type"))
        self._type   = type
        self.set_port(port)
        self.set_keymap(keymap)
        self.set_listen(listen)
        self.set_passwd(passwd)

    def get_type(self):
        return self._type
    type = property(get_type)

    def get_keymap(self):
        return self._keymap
    def set_keymap(self, val):
        if not val:
            val = _util.default_keymap()
        if not val or type(val) != type("string"):
            raise ValueError, _("Keymap must be a string")
        if len(val) > 16:
            raise ValueError, _("Keymap must be less than 16 characters")
        if re.match("^[a-zA-Z0-9_-]*$", val) == None:
            raise ValueError, _("Keymap can only contain alphanumeric, '_', or '-' characters")
        self._keymap = val
    keymap = property(get_keymap, set_keymap)

    def get_port(self):
        return self._port
    def set_port(self, val):
        if val is None:
            val = -1
        elif type(val) is not int \
             or (val != -1 and (val < 5900 or val > 65535)):
            raise ValueError, _("VNC port must be a number between 5900 and 65535, or -1 for auto allocation")
        self._port = val
    port = property(get_port, set_port)

    def get_listen(self):
        return self._listen
    def set_listen(self, val):
        self._listen = val
    listen = property(get_listen, set_listen)

    def get_passwd(self):
        return self._passwd
    def set_passwd(self, val):
        self._passwd = val
    passwd = property(get_passwd, set_passwd)

    def get_xml_config(self):
        if self._type == self.TYPE_SDL:
            return "    <graphics type='sdl'/>"
        keymapxml = ""
        listenxml = ""
        passwdxml = ""
        if self.keymap:
            keymapxml = " keymap='%s'" % self._keymap
        if self.listen:
            listenxml = " listen='%s'" % self._listen
        if self.passwd:
            passwdxml = " passwd='%s'" % self._passwd
        xml = "    <graphics type='vnc' " + \
                   "port='%(port)d'" % { "port" : self._port } + \
                   "%(keymapxml)s"   % { "keymapxml" : keymapxml } + \
                   "%(listenxml)s"   % { "listenxml" : listenxml } + \
                   "%(passwdxml)s"   % { "passwdxml" : passwdxml } + \
                   "/>"
        return xml

class Installer(object):
    def __init__(self, type = "xen", location = None, boot = None,
                 extraargs = None, os_type = None, conn = None):
        self._location = None
        self._extraargs = None
        self._boot = None
        self._cdrom = False
        self._os_type = os_type
        self._conn = conn
        self._install_disk = None   # VirtualDisk that contains install media

        if type is None:
            type = "xen"
        self.type = type

        if not location is None:
            self.location = location
        if not boot is None:
            self.boot = boot
        if not extraargs is None:
            self.extraargs = extraargs

        self._tmpfiles = []

    def get_install_disk(self):
        return self._install_disk
    install_disk = property(get_install_disk)

    def get_conn(self):
        return self._conn
    conn = property(get_conn)

    def get_type(self):
        return self._type
    def set_type(self, val):
        self._type = val
    type = property(get_type, set_type)

    def get_os_type(self):
        return self._os_type
    def set_os_type(self, val):
        self._os_type = val
    os_type = property(get_os_type, set_os_type)

    def get_scratchdir(self):
        if platform.system() == 'SunOS':
            return '/var/tmp'
        if self.type == "xen" and os.path.exists(XEN_SCRATCH):
            return XEN_SCRATCH
        if os.geteuid() == 0 and os.path.exists(LIBVIRT_SCRATCH):
            return LIBVIRT_SCRATCH
        else:
            return os.path.expanduser("~/.virtinst/boot")
    scratchdir = property(get_scratchdir)

    def get_cdrom(self):
        return self._cdrom
    def set_cdrom(self, enable):
        if enable not in [True, False]:
            raise ValueError, _("Guest.cdrom must be a boolean type")
        self._cdrom = enable
    cdrom = property(get_cdrom, set_cdrom)

    def get_location(self):
        return self._location
    def set_location(self, val):
        self._location = val
    location = property(get_location, set_location)

    # kernel + initrd pair to use for installing as opposed to using a location
    def get_boot(self):
        return self._boot
    def set_boot(self, val):
        self.cdrom = False
        if type(val) == tuple:
            if len(val) != 2:
                raise ValueError, _("Must pass both a kernel and initrd")
            (k, i) = val
            self._boot = {"kernel": k, "initrd": i}
        elif type(val) == dict:
            if not val.has_key("kernel") or not val.has_key("initrd"):
                raise ValueError, _("Must pass both a kernel and initrd")
            self._boot = val
        elif type(val) == list:
            if len(val) != 2:
                raise ValueError, _("Must pass both a kernel and initrd")
            self._boot = {"kernel": val[0], "initrd": val[1]}
        else:
            raise ValueError, _("Kernel and initrd must be specified by a list, dict, or tuple.")
    boot = property(get_boot, set_boot)

    # extra arguments to pass to the guest installer
    def get_extra_args(self):
        return self._extraargs
    def set_extra_args(self, val):
        self._extraargs = val
    extraargs = property(get_extra_args, set_extra_args)

    # Private methods

    def _get_osblob_helper(self, isinstall, ishvm, arch=None, loader=None,
                           conn=None, kernel=None, bootdev=None):
        osblob = ""
        if not isinstall and not ishvm:
            return "<bootloader>%s</bootloader>" % _util.pygrub_path(conn)

        osblob = "<os>\n"

        os_type = self.os_type
        # Hack for older libvirt Xen driver
        if os_type == "xen" and self.type == "xen":
            os_type = "linux"

        if arch:
            osblob += "    <type arch='%s'>%s</type>\n" % (arch, os_type)
        else:
            osblob += "    <type>%s</type>\n" % os_type

        if loader:
            osblob += "    <loader>%s</loader>\n" % loader

        if isinstall and kernel and kernel["kernel"]:
            osblob += "    <kernel>%s</kernel>\n"   % _util.xml_escape(kernel["kernel"])
            osblob += "    <initrd>%s</initrd>\n"   % _util.xml_escape(kernel["initrd"])
            osblob += "    <cmdline>%s</cmdline>\n" % _util.xml_escape(kernel["extraargs"])
        elif bootdev is not None:
            osblob += "    <boot dev='%s'/>\n" % bootdev

        osblob += "  </os>"

        return osblob


    # Method definitions

    def cleanup(self):
        """
        Remove any temporary files retrieved during installation
        """
        for f in self._tmpfiles:
            logging.debug("Removing " + f)
            os.unlink(f)
        self._tmpfiles = []

    def prepare(self, guest, meter, distro=None):
        """
        Fetch any files needed for installation.
        @param guest: guest instance being installed
        @type L{Guest}
        @param meter: progress meter
        @type Urlgrabber ProgressMeter
        @param distro: Name of distro being installed
        @type C{str} name from Guest os dictionary
        """
        raise NotImplementedError("Must be implemented in subclass")

    def post_install_check(self, guest):
        """
        Attempt to verify that installing to disk was successful.
        @param guest: guest instance that was installed
        @type L{Guest}
        """

        if _util.is_uri_remote(guest.conn.getURI()):
            # XXX: Use block peek for this?
            return True

        if len(guest.disks) == 0 \
           or guest.disks[0].device != VirtualDisk.DEVICE_DISK:
            return True

        if _util.is_vdisk(guest.disks[0].path):
            return True

        # Check for the 0xaa55 signature at the end of the MBR
        try:
            fd = os.open(guest.disks[0].path, os.O_RDONLY)
        except OSError, (err, msg):
            logging.debug("Failed to open guest disk: %s" % msg)
            if err == errno.EACCES and os.geteuid() != 0:
                return True # non root might not have access to block devices
            else:
                raise
        buf = os.read(fd, 512)
        os.close(fd)
        return (len(buf) == 512 and
                struct.unpack("H", buf[0x1fe: 0x200]) == (0xaa55,))

class Guest(object):

    # OS Dictionary static variables and methods
    _DEFAULTS = osdict.DEFAULTS
    _OS_TYPES = osdict.OS_TYPES

    def list_os_types():
        return osdict.sort_helper(Guest._OS_TYPES)
    list_os_types = staticmethod(list_os_types)

    def list_os_variants(type):
        return osdict.sort_helper(Guest._OS_TYPES[type]["variants"])
    list_os_variants = staticmethod(list_os_variants)

    def get_os_type_label(type):
        return Guest._OS_TYPES[type]["label"]
    get_os_type_label = staticmethod(get_os_type_label)

    def get_os_variant_label(type, variant):
        return Guest._OS_TYPES[type]["variants"][variant]["label"]
    get_os_variant_label = staticmethod(get_os_variant_label)

    def __init__(self, type=None, connection=None, hypervisorURI=None,
                 installer=None):
        # We specifically ignore the 'type' parameter here, since
        # it has been replaced by installer.type, and child classes can
        # use it when creating a default installer.
        self._installer = installer
        self._name = None
        self._uuid = None
        self._memory = None
        self._maxmemory = None
        self._vcpus = None
        self._cpuset = None
        self._graphics_dev = None

        self._os_type = None
        self._os_variant = None

        # Public device lists unaltered by install process
        self.disks = []
        self.nics = []
        self.sound_devs = []

        # Device lists to use/alter during install process
        self._install_disks = []
        self._install_nics = []

        self.domain = None
        self.conn = connection
        if self.conn == None:
            logging.debug("No conn passed to Guest, opening URI '%s'" % \
                          hypervisorURI)
            self.conn = libvirt.open(hypervisorURI)
        if self.conn == None:
            raise RuntimeError, _("Unable to connect to hypervisor, aborting "
                                  "installation!")
        self._caps = CapabilitiesParser.parse(self.conn.getCapabilities())

        self.disknode = None # this needs to be set in the subclass

    def get_installer(self):
        return self._installer
    def set_installer(self, val):
        self._installer = val
    installer = property(get_installer, set_installer)


    def get_type(self):
        return self._installer.type
    def set_type(self, val):
        self._installer.type = val
    type = property(get_type, set_type)


    # Domain name of the guest
    def get_name(self):
        return self._name
    def set_name(self, val):
        if type(val) is not type("string") or len(val) > 50 or len(val) == 0:
            raise ValueError, _("System name must be a string greater than 0 and no more than 50 characters")
        if re.match("^[0-9]+$", val):
            raise ValueError, _("System name must not be only numeric characters")
        if re.match("^[A-Za-z0-9_.:/+-]+$", val) == None:
            raise ValueError, _("System name can only contain: alphanumeric "
                                "'_', '.', ':', '+', or '-' characters")
        self._name = val
    name = property(get_name, set_name)


    # Memory allocated to the guest.  Should be given in MB
    def get_memory(self):
        return self._memory
    def set_memory(self, val):
        if (type(val) is not type(1) or val <= 0):
            raise ValueError, _("Memory value must be an integer greater than 0")
        self._memory = val
        if self._maxmemory is None or self._maxmemory < val:
            self._maxmemory = val
    memory = property(get_memory, set_memory)

    # Memory allocated to the guest.  Should be given in MB
    def get_maxmemory(self):
        return self._maxmemory
    def set_maxmemory(self, val):
        if (type(val) is not type(1) or val <= 0):
            raise ValueError, _("Max Memory value must be an integer greater than 0")
        self._maxmemory = val
    maxmemory = property(get_maxmemory, set_maxmemory)


    # UUID for the guest
    def get_uuid(self):
        return self._uuid
    def set_uuid(self, val):
        # need better validation
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


    # number of vcpus for the guest
    def get_vcpus(self):
        return self._vcpus
    def set_vcpus(self, val):
        maxvcpus = _util.get_max_vcpus(self.conn, self.type)
        if type(val) is not int or val < 1:
            raise ValueError, _("Number of vcpus must be a postive integer.")
        if val > maxvcpus:
            raise ValueError, \
                  _("Number of vcpus must be no greater than %d for this vm type.") % maxvcpus
        self._vcpus = val
    vcpus = property(get_vcpus, set_vcpus)

    # set phy-cpus for the guest
    def get_cpuset(self):
        return self._cpuset
    def set_cpuset(self, val):
        if type(val) is not type("string") or len(val) == 0:
            raise ValueError, _("cpuset must be string")
        if re.match("^[0-9,-]*$", val) is None:
            raise ValueError, _("cpuset can only contain numeric, ',', or '-' characters")

        pcpus = _util.get_phy_cpus(self.conn)
        for c in val.split(','):
            if c.find('-') != -1:
                (x, y) = c.split('-')
                if int(x) > int(y):
                    raise ValueError, _("cpuset contains invalid format.")
                if int(x) >= pcpus or int(y) >= pcpus:
                    raise ValueError, _("cpuset's pCPU numbers must be less than pCPUs.")
            else:
                if int(c) >= pcpus:
                    raise ValueError, _("cpuset's pCPU numbers must be less than pCPUs.")
        self._cpuset = val
    cpuset = property(get_cpuset, set_cpuset)

    def get_graphics_dev(self):
        return self._graphics_dev
    def set_graphics_dev(self, val):
        self._graphics_dev = val
    graphics_dev = property(get_graphics_dev, set_graphics_dev)

    def get_os_type(self):
        return self._os_type
    def set_os_type(self, val):
        if type(val) is not str:
            raise ValueError(_("OS type must be a string."))
        val = val.lower()
        if self._OS_TYPES.has_key(val):
            self._os_type = val
            # Invalidate variant, since it may not apply to the new os type
            self._os_variant = None
        else:
            raise ValueError, _("OS type '%s' does not exist in our "
                                "dictionary") % val
    os_type = property(get_os_type, set_os_type)

    def get_os_variant(self):
        return self._os_variant
    def set_os_variant(self, val):
        if type(val) is not str:
            raise ValueError(_("OS variant must be a string."))
        val = val.lower()
        if self.os_type:
            if self._OS_TYPES[self.os_type]["variants"].has_key(val):
                self._os_variant = val
            else:
                raise ValueError, _("OS variant '%(var)s; does not exist in "
                                    "our dictionary for OS type '%(ty)s'" ) % \
                                    {'var' : val, 'ty' : self._os_type}
        else:
            for ostype in self.list_os_types():
                if self._OS_TYPES[ostype]["variants"].has_key(val) and \
                   not self._OS_TYPES[ostype]["variants"][val].get("skip"):
                    logging.debug("Setting os type to '%s' for variant '%s'" %\
                                  (ostype, val))
                    self.os_type = ostype
                    self._os_variant = val
                    return
            raise ValueError, _("Unknown OS variant '%s'" % val)
    os_variant = property(get_os_variant, set_os_variant)


    # DEPRECATED PROPERTIES
    # Deprecated: Should set graphics_dev.keymap directly
    def get_keymap(self):
        if self._graphics_dev is None:
            return None
        return self._graphics_dev.keymap
    def set_keymap(self, val):
        if self._graphics_dev is not None:
            self._graphics_dev.keymap = val
    keymap = property(get_keymap, set_keymap)

    # Deprecated: Should set guest.graphics_dev = VirtualGraphics(...)
    def get_graphics(self):
        if self._graphics_dev is None:
            return { "enabled" : False }
        return { "enabled" : True, "type" : self._graphics_dev, \
                 "keymap"  : self._graphics_dev.keymap}
    def set_graphics(self, val):

        # val can be:
        #   a dictionary with keys:  enabled, type, port, keymap
        #   a tuple of the form   : (enabled, type, port, keymap)
        #                            last 2 optional
        #                         : "vnc", "sdl", or false
        port = None
        gtype = None
        enabled = False
        keymap = None
        gdev = None
        if type(val) == dict:
            if not val.has_key("enabled"):
                raise ValueError, _("Must specify whether graphics are enabled")
            enabled = val["enabled"]
            if val.has_key("type"):
                gtype = val["type"]
                if val.has_key("opts"):
                    port = val["opts"]
        elif type(val) == tuple:
            if len(val) >= 1:
                enabled = val[0]
            if len(val) >= 2:
                gtype = val[1]
            if len(val) >= 3:
                port = val[2]
            if len(val) >= 4:
                keymap = val[3]
        else:
            if val in ("vnc", "sdl"):
                gtype = val
                enabled = True
            else:
                enabled = val

        if enabled not in (True, False):
            raise ValueError, _("Graphics enabled must be True or False")

        if enabled == True:
            gdev = VirtualGraphics(type=gtype)
            if port:
                gdev.port = port
            if keymap:
                gdev.keymap = keymap
        self._graphics_dev = gdev

    graphics = property(get_graphics, set_graphics)

    # Deprecated: Should be called from the installer directly
    def get_location(self):
        return self._installer.location
    def set_location(self, val):
        self._installer.location = val
    location = property(get_location, set_location)

    # Deprecated: Should be called from the installer directly
    def get_scratchdir(self):
        return self._installer.scratchdir
    scratchdir = property(get_scratchdir)

    # Deprecated: Should be called from the installer directly
    def get_boot(self):
        return self._installer.boot
    def set_boot(self, val):
        self._installer.boot = val
    boot = property(get_boot, set_boot)

    # Deprecated: Should be called from the installer directly
    def get_extraargs(self):
        return self._installer.extraargs
    def set_extraargs(self, val):
        self._installer.extraargs = val
    extraargs = property(get_extraargs, set_extraargs)

    # Deprecated: Should set the installer values directly
    def get_cdrom(self):
        return self._installer.location
    def set_cdrom(self, val):
        if val is None or type(val) is not type("string") or len(val) == 0:
            raise ValueError, _("You must specify a valid ISO or CD-ROM location for the installation")
        if val.startswith("/"):
            if not os.path.exists(val):
                raise ValueError, _("The specified media path does not exist.")
            self._installer.location = os.path.abspath(val)
        else:
            # Assume its a http/nfs/ftp style path
            self._installer.location = val
        self._installer.cdrom = True
    cdrom = property(get_cdrom, set_cdrom)
    # END DEPRECATED PROPERTIES

    def _create_devices(self,progresscb):
        """Ensure that devices are setup"""
        for disk in self._install_disks:
            disk.setup(progresscb)
        for nic in self._install_nics:
            nic.setup(self.conn)

    def _get_disk_xml(self, install=True):
        """Return xml for disk devices (Must be implemented in subclass)"""
        raise NotImplementedError

    def _get_network_xml(self):
        """Get the network config in the libvirt XML format"""
        ret = ""
        for n in self._install_nics:
            if ret:
                ret += "\n"
            ret += n.get_xml_config()
        return ret

    def _get_graphics_xml(self):
        """Get the graphics config in the libvirt XML format."""
        if self._graphics_dev is None:
            return ""
        return self._graphics_dev.get_xml_config()

    def _get_input_device(self):
        """ Return a tuple of the form (devtype, bus) for the desired
            input device. (Must be implemented in subclass) """
        raise NotImplementedError

    def _get_input_xml(self):
        """Get the input device config in libvirt XML format."""
        (devtype, bus) = self._get_input_device()
        return "    <input type='%s' bus='%s'/>" % (devtype, bus)

    def _get_sound_xml(self):
        """Get the sound device configuration in libvirt XML format."""
        xml = ""
        for sound_dev in self.sound_devs:
            if xml != "":
                xml += "\n"
            xml += sound_dev.get_xml_config()
        return xml

    def _get_device_xml(self, install=True):

        xml = ""
        diskxml     = self._get_disk_xml(install)
        netxml      = self._get_network_xml()
        inputxml    = self._get_input_xml()
        graphicsxml = self._get_graphics_xml()
        soundxml    = self._get_sound_xml()
        for devxml in [diskxml, netxml, inputxml, graphicsxml, soundxml]:
            if devxml:
                if xml:
                    xml += "\n"
                xml += devxml
        return xml

    def _get_osblob(self, install):
        """Return os, features, and clock xml (Implemented in subclass)"""
        raise NotImplementedError

    def get_config_xml(self, install = True, disk_boot = False):
        if install:
            action = "destroy"
        else:
            action = "restart"

        osblob_install = install
        if disk_boot:
            osblob_install = False

        osblob = self._get_osblob(osblob_install)
        if not osblob:
            return None

        if self.cpuset is not None:
            cpuset = " cpuset='" + self.cpuset + "'"
        else:
            cpuset = ""

        return """<domain type='%(type)s'>
  <name>%(name)s</name>
  <currentMemory>%(ramkb)s</currentMemory>
  <memory>%(maxramkb)s</memory>
  <uuid>%(uuid)s</uuid>
  %(osblob)s
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>%(action)s</on_reboot>
  <on_crash>%(action)s</on_crash>
  <vcpu%(cpuset)s>%(vcpus)d</vcpu>
  <devices>
%(devices)s
  </devices>
</domain>
""" % { "type": self.type,
        "name": self.name, \
        "vcpus": self.vcpus, \
        "cpuset": cpuset, \
        "uuid": self.uuid, \
        "ramkb": self.memory * 1024, \
        "maxramkb": self.maxmemory * 1024, \
        "devices": self._get_device_xml(install), \
        "osblob": osblob, \
        "action": action }


    def start_install(self, consolecb=None, meter=None, removeOld=False,
                      wait=True):
        """Do the startup of the guest installation."""
        self.validate_parms()

        if meter is None:
            # BaseMeter does nothing, but saves a lot of null checking
            meter = progress.BaseMeter()

        self._prepare_install(meter)
        try:
            return self._do_install(consolecb, meter, removeOld, wait)
        finally:
            self._installer.cleanup()

    def _prepare_install(self, meter):
        self._install_disks = self.disks[:]
        self._install_nics = self.nics[:]
        self._set_defaults()

        self._installer.prepare(guest = self,
                                meter = meter)
        if self._installer.install_disk is not None:
            self._install_disks.append(self._installer.install_disk)

    def _do_install(self, consolecb, meter, removeOld=False, wait=True):
        vm = None
        try:
            vm = self.conn.lookupByName(self.name)
        except libvirt.libvirtError:
            pass

        if vm is not None:
            if removeOld :
                try:
                    if vm.ID() != -1:
                        logging.info("Destroying image %s" %(self.name))
                        vm.destroy()
                    logging.info("Removing old definition for image %s" %(self.name))
                    vm.undefine()
                except libvirt.libvirtError, e:
                    raise RuntimeError, _("Could not remove old vm '%s': %s") %(self.name, str(e))
            else:
                raise RuntimeError, _("Domain named %s already exists!") %(self.name,)

        child = None
        self._create_devices(meter)
        install_xml = self.get_config_xml()
        if install_xml:
            logging.debug("Creating guest from:\n%s" % install_xml)
            meter.start(size=None, text=_("Creating domain..."))
            self.domain = self.conn.createLinux(install_xml, 0)
            if self.domain is None:
                raise RuntimeError, _("Unable to create domain for the guest, aborting installation!")
            meter.end(0)

            logging.debug("Created guest, looking to see if it is running")

            d = _wait_for_domain(self.conn, self.name)

            if d is None:
                raise RuntimeError, _("It appears that your installation has crashed.  You should be able to find more information in the logs")

            if consolecb:
                logging.debug("Launching console callback")
                child = consolecb(self.domain)

        boot_xml = self.get_config_xml(install = False)
        logging.debug("Saving XML boot config:\n%s" % boot_xml)
        self.conn.defineXML(boot_xml)

        if child and wait: # if we connected the console, wait for it to finish
            try:
                os.waitpid(child, 0)
            except OSError, (err_no, msg):
                print __name__, "waitpid: %s: %s" % (err_no, msg)

            # ensure there's time for the domain to finish destroying if the
            # install has finished or the guest crashed
            time.sleep(1)

        # This should always work, because it'll lookup a config file
        # for inactive guest, or get the still running install..
        return self.conn.lookupByName(self.name)

    def post_install_check(self):
        return self.installer.post_install_check(self)

    def connect_console(self, consolecb, wait=True):
        logging.debug("Restarted guest, looking to see if it is running")

        self.domain = _wait_for_domain(self.conn, self.name)

        if self.domain is None:
            raise RuntimeError, _("Domain has not existed.  You should be able to find more information in the logs")
        elif self.domain.ID() == -1:
            raise RuntimeError, _("Domain has not run yet.  You should be able to find more information in the logs")

        child = None
        if consolecb:
            logging.debug("Launching console callback")
            child = consolecb(self.domain)

        if child and wait: # if we connected the console, wait for it to finish
            try:
                os.waitpid(child, 0)
            except OSError, (err_no, msg):
                raise RuntimeError, \
                      "waiting console pid error: %s: %s" % (err_no, msg)

    def validate_parms(self):
        if self.domain is not None:
            raise RuntimeError, _("Domain has already been started!")

    def _set_defaults(self):
        if self.uuid is None:
            while 1:
                self.uuid = _util.uuidToString(_util.randomUUID())
                if _util.vm_uuid_collision(self.conn, self.uuid):
                    continue
                break
        else:
            if _util.vm_uuid_collision(self.conn, self.uuid):
                raise RuntimeError, _("The UUID you entered is already in "
                                      "use by another guest!")
        if self.vcpus is None:
            self.vcpus = 1
        if self.name is None or self.memory is None:
            raise RuntimeError, _("Name and memory must be specified for all guests!")

    # Guest Dictionary Helper methods

    def _lookup_osdict_key(self, key):
        """
        Using self.os_type and self.os_variant to find key in OSTYPES
        @returns: dict value, or None if os_type/variant wasn't set
        """
        typ = self.os_type
        var = self.os_variant
        if typ:
            if var and self._OS_TYPES[typ]["variants"][var].has_key(key):
                return self._OS_TYPES[typ]["variants"][var][key]
            elif self._OS_TYPES[typ].has_key(key):
                return self._OS_TYPES[typ][key]
        return self._DEFAULTS[key]

    def _lookup_device_param(self, device_key, param):
        """
        Check the OS dictionary for the prefered device setting for passed
        device type and param (bus, model, etc.)
        """
        os_devs = self._lookup_osdict_key("devices")
        default_devs = self._DEFAULTS["devices"]
        for devs in [os_devs, default_devs]:
            if not devs.has_key(device_key):
                continue
            for ent in devs[device_key][param]:
                hv_types = ent[0]
                param_value = ent[1]
                if self.type in hv_types:
                    return param_value
                elif "all" in hv_types:
                    return param_value
        raise RuntimeError(_("Invalid dictionary entry for device '%s %s'" % \
                             (device_key, param)))

def _wait_for_domain(conn, name):
    # sleep in .25 second increments until either a) we get running
    # domain ID or b) it's been 5 seconds.  this is so that
    # we can try to gracefully handle domain restarting failures
    dom = None
    for ignore in range(1, (5 / .25)): # 5 seconds, .25 second sleeps
        try:
            dom = conn.lookupByName(name)
            if dom and dom.ID() != -1:
                break
        except libvirt.libvirtError, e:
            logging.debug("No guest running yet: " + str(e))
            dom = None
        time.sleep(0.25)

    return dom

# Back compat class to avoid ABI break
XenGuest = Guest
