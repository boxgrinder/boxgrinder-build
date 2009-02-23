#
# Some code for parsing libvirt's capabilities XML
#
# Copyright 2007  Red Hat, Inc.
# Mark McLoughlin <markmc@redhat.com>
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

import libxml2
from virtinst import _virtinst as _

class CapabilitiesParserException(Exception):
    def __init__(self, msg):
        Exception.__init__(self, msg)

# Whether a guest can be created with a certain feature on resp. off
FEATURE_ON      = 0x01
FEATURE_OFF     = 0x02

class Features(object):
    """Represent a set of features. For each feature, store a bit mask of
       FEATURE_ON and FEATURE_OFF to indicate whether the feature can
       be turned on or off. For features for which toggling doesn't make sense
       (e.g., 'vmx') store FEATURE_ON when the feature is present."""

    def __init__(self, node = None):
        self.features = {}
        if node is not None:
            self.parseXML(node)

    def __getitem__(self, feature):
        if self.features.has_key(feature):
            return self.features[feature]
        return 0

    def names(self):
        return self.features.keys()

    def parseXML(self, node):
        d = self.features
        for n in node.xpathEval("*"):
            feature = n.name
            if not d.has_key(feature):
                d[feature] = 0

            self._extractFeature(feature, d, n)

    def _extractFeature(self, feature, d, node):
        """Extract the value of FEATURE from NODE and set DICT[FEATURE] to
        its value. Abstract method, must be overridden"""
        raise NotImplementedError("Abstract base class")

class CapabilityFeatures(Features):
    def __init__(self, node = None):
        Features.__init__(self, node)

    def _extractFeature(self, feature, d, n):
        default = xpathString(n, "@default")
        toggle = xpathString(n, "@toggle")

        if default is not None:
            if default == "on":
                d[feature] = FEATURE_ON
            elif default == "off":
                d[feature] = FEATURE_OFF
            else:
                raise CapabilitiesParserException("Feature %s: value of default must be 'on' or 'off', but is '%s'" % (feature, default))
            if toggle == "yes":
                d[feature] |= d[feature] ^ (FEATURE_ON|FEATURE_OFF)
        else:
            if feature == "nonpae":
                d["pae"] |= FEATURE_OFF
            else:
                d[feature] |= FEATURE_ON

class Host(object):
    def __init__(self, node = None):
        # e.g. "i686" or "x86_64"
        self.arch = None

        self.features = CapabilityFeatures()
        self.topology = None

        if not node is None:
            self.parseXML(node)

    def parseXML(self, node):
        child = node.children
        while child:
            if child.name == "topology":
                self.topology = Topology(child)

            if child.name != "cpu":
                child = child.next
                continue

            n = child.children
            while n:
                if n.name == "arch":
                    self.arch = n.content
                elif n.name == "features":
                    self.features = CapabilityFeatures(n)
                n = n.next

            child = child.next


class Guest(object):
    def __init__(self, node = None):
        # e.g. "xen" or "hvm"
        self.os_type = None
        # e.g. "i686" or "x86_64"
        self.arch = None

        self.domains = []

        self.features = CapabilityFeatures()

        if not node is None:
            self.parseXML(node)

    def parseXML(self, node):
        child = node.children
        while child:
            if child.name == "os_type":
                self.os_type = child.content
            elif child.name == "features":
                self.features = CapabilityFeatures(child)
            elif child.name == "arch":
                self.arch = child.prop("name")
                machines = []
                emulator = None
                loader = None
                n = child.children
                while n:
                    if n.name == "machine":
                        machines.append(n.content)
                    elif n.name == "emulator":
                        emulator = n.content
                    elif n.name == "loader":
                        loader = n.content
                    n = n.next

                n = child.children
                while n:
                    if n.name == "domain":
                        self.domains.append(Domain(n.prop("type"), emulator, loader, machines, n))
                    n = n.next

            child = child.next


    def bestDomainType(self, accelerated=None):
        if len(self.domains) == 0:
            raise CapabilitiesParserException(_("No domains available for this guest."))
        if accelerated is None:
            # Picking last in list so we favour KVM/KQEMU over QEMU
            return self.domains[-1]
        else:
            priority = ["kvm", "xen", "kqemu", "qemu"]
            if not accelerated:
                priority.reverse()

            for t in priority:
                for d in self.domains:
                    if d.hypervisor_type == t:
                        return d

            # Fallback, just return last item in list
            return self.domains[-1]


class Domain(object):
    def __init__(self, hypervisor_type, emulator = None, loader = None, machines = None, node = None):
        self.hypervisor_type = hypervisor_type
        self.emulator = emulator
        self.loader = loader
        self.machines = machines

        if node is not None:
            self.parseXML(node)


    def parseXML(self, node):
        child = node.children
        machines = []
        while child:
            if child.name == "emulator":
                self.emulator = child.content
            elif child.name == "machine":
                machines.append(child.content)
            child = child.next

        if len(machines) > 0:
            self.machines = machines

class Topology(object):
    def __init__(self, node = None):
        self.cells = []

        if not node is None:
            self.parseXML(node)

    def parseXML(self, node):
        child = node.children
        if child.name == "cells":
            for cell in child.children:
                if cell.name == "cell":
                    self.cells.append(TopologyCell(cell))

class TopologyCell(object):
    def __init__(self, node = None):
        self.id = None
        self.cpus = []

        if not node is None:
            self.parseXML(node)

    def parseXML(self, node):
        self.id = int(node.prop("id"))
        child = node.children
        if child.name == "cpus":
            for cpu in child.children:
                if cpu.name == "cpu":
                    self.cpus.append(TopologyCPU(cpu))

class TopologyCPU(object):
    def __init__(self, node = None):
        self.id = None

        if not node is None:
            self.parseXML(node)

    def parseXML(self, node):
        self.id = int(node.prop("id"))


class Capabilities(object):
    def __init__(self, node = None):
        self.host = None
        self.guests = []
        self._topology = None

        if not node is None:
            self.parseXML(node)


        self._fixBrokenEmulator()

    def guestForOSType(self, type = None, arch = None):
        if self.host is None:
            return None

        if arch is None:
            archs = [self.host.arch, None]
        else:
            archs = [arch]
        for a in archs:
            for g in self.guests:
                if (type is None or g.os_type == type) and \
                   (a is None or g.arch == a):
                    return g

    # 32-bit HVM emulator path, on a 64-bit host is wrong due
    # to bug in libvirt capabilities. We fix by copying the
    # 64-bit emualtor path
    def _fixBrokenEmulator(self):
        if self.host.arch != "x86_64":
            return

        fixEmulator = None
        for g in self.guests:
            if g.os_type != "hvm" or g.arch != "x86_64":
                continue
            for d in g.domains:
                if d.emulator.find("lib64") != -1:
                    fixEmulator = d.emulator

        if not fixEmulator:
            return

        for g in self.guests:
            if g.os_type != "hvm" or g.arch != "i686":
                continue
            for d in g.domains:
                if d.emulator.find("lib64") == -1:
                    d.emulator = fixEmulator

    def parseXML(self, node):
        child = node.children
        while child:
            if child.name == "host":
                self.host = Host(child)
            elif child.name == "guest":
                self.guests.append(Guest(child))
            if child.name == "topology":
                self._topology = Topology(child)
            child = child.next

        # Libvirt < 0.4.1 placed topology info at the capabilities level
        # rather than the host level. This is just for back compat
        if self.host.topology is None:
            self.host.topology = self._topology

def parse(xml):
    class ErrorHandler:
        def __init__(self):
            self.msg = ""
        def handler(self, ignore, s):
            self.msg += s
    error = ErrorHandler()
    libxml2.registerErrorHandler(error.handler, None)

    try:
        # try/except/finally is only available in python-2.5
        try:
            doc = libxml2.readMemory(xml, len(xml),
                                     None, None,
                                     libxml2.XML_PARSE_NOBLANKS)
        except (libxml2.parserError, libxml2.treeError), e:
            raise CapabilitiesParserException("%s\n%s" % (e, error.msg))
    finally:
        libxml2.registerErrorHandler(None, None)

    try:
        root = doc.getRootElement()
        if root.name != "capabilities":
            raise CapabilitiesParserException("Root element is not 'capabilities'")

        capabilities = Capabilities(root)
    finally:
        doc.freeDoc()

    return capabilities

def xpathString(node, path, default = None):
    result = node.xpathEval("string(%s)" % path)
    if len(result) == 0:
        result = default
    return result
