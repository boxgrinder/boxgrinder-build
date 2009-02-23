#
# Represents OS distribution specific install data
#
# Copyright 2006-2007  Red Hat, Inc.
# Daniel P. Berrange <berrange@redhat.com>
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

import logging
import os
import gzip
import re
import tempfile
import platform
import socket
import ConfigParser

from virtinst import _util
from virtinst import _virtinst as _

def distroFromTreeinfo(fetcher, progresscb, uri, vmtype=None,
                       scratchdir=None, arch=None):
    # Parse treeinfo 'family' field, and return the associated Distro class
    # None if no treeinfo, GenericDistro if unknown family type.
    if not fetcher.hasFile(".treeinfo"):
        return None

    tmptreeinfo = fetcher.acquireFile(".treeinfo", progresscb)
    try:
        treeinfo = ConfigParser.SafeConfigParser()
        treeinfo.read(tmptreeinfo)
    finally:
        os.unlink(tmptreeinfo)

    fam = treeinfo.get("general", "family")

    if re.match(".*Fedora.*", fam):
        ob = FedoraDistro(uri, vmtype, scratchdir, arch)
    elif re.match(".*CentOS.*", fam):
        ob = CentOSDistro(uri, vmtype, scratchdir, arch)
    elif re.match(".*Red Hat Enterprise Linux.*", fam):
        ob = RHELDistro(uri, vmtype, scratchdir, arch)
    elif re.match(".*Scientific Linux.*", fam):
        ob = SLDistro(uri, vmtype, scratchdir, arch)
    else:
        ob = GenericDistro(uri, vmtype, scratchdir, arch)

    ob.treeinfo = treeinfo
    return ob


# An image store is a base class for retrieving either a bootable
# ISO image, or a kernel+initrd  pair for a particular OS distribution
class Distro:

    name = ""
    _boot_iso_paths = []
    _hvm_kernel_paths = []
    _xen_kernel_paths = []
    uses_treeinfo = False

    def __init__(self, uri, vmtype=None, scratchdir=None, arch=None):
        self.uri = uri
        self.type = vmtype
        self.scratchdir = scratchdir
        if arch == None:
            arch = platform.machine()
        self.arch = arch
        self.treeinfo = None

    def isValidStore(self, fetcher, progresscb):
        """Determine if uri points to a tree of the store's distro"""
        raise NotImplementedError

    def acquireKernel(self, guest, fetcher, progresscb):
        kernelpath = None
        initrdpath = None
        if self._hasTreeinfo(fetcher, progresscb):
            kernelpath = self._getTreeinfoMedia("kernel")
            initrdpath = self._getTreeinfoMedia("initrd")
        else:
            # fall back to old code
            if self.type is None or self.type == "hvm":
                paths = self._hvm_kernel_paths
            else:
                paths = self._xen_kernel_paths

            for kpath, ipath in paths:
                if fetcher.hasFile(kpath) and fetcher.hasFile(ipath):
                    kernelpath = kpath
                    initrdpath = ipath

        if not kernelpath or not initrdpath:
            raise RuntimeError(_("Couldn't find %(type)s kernel for "
                                 "%(distro)s tree.") % \
                                 { "distro": self.name, "type" : self.type })

        return self._kernelFetchHelper(fetcher, guest, progresscb, kernelpath,
                                       initrdpath)

    def acquireBootDisk(self, fetcher, progresscb):
        if self._hasTreeinfo(fetcher, progresscb):
            return fetcher.acquireFile(self._getTreeinfoMedia("boot.iso"))
        else:
            for path in self._boot_iso_paths:
                if fetcher.hasFile(path):
                    return fetcher.acquireFile(path, progresscb)
            raise RuntimeError(_("Could not find boot.iso in %s tree." % \
                               self.name))


    def _hasTreeinfo(self, fetcher, progresscb):
        # all Red Hat based distros should have .treeinfo, perhaps others
        # will in time
        if not (self.treeinfo is None):
            return True

        if not self.uses_treeinfo or not fetcher.hasFile(".treeinfo"):
            return False

        logging.debug("Detected .treeinfo file")

        tmptreeinfo = fetcher.acquireFile(".treeinfo", progresscb)
        try:
            self.treeinfo = ConfigParser.SafeConfigParser()
            self.treeinfo.read(tmptreeinfo)
        finally:
            os.unlink(tmptreeinfo)
        return True

    def _getTreeinfoMedia(self, mediaName):
        if self.type == "xen":
            t = "xen"
        else:
            t = self.treeinfo.get("general", "arch")

        return self.treeinfo.get("images-%s" % t, mediaName)

    def _fetchAndMatchRegex(self, fetcher, progresscb, filename, regex):
        # Fetch 'filename' and return True/False if it matches the regex
        local_file = None
        try:
            try:
                local_file = fetcher.acquireFile(filename, progresscb)
            except:
                return False

            f = open(local_file, "r")
            try:
                while 1:
                    buf = f.readline()
                    if not buf:
                        break
                    if re.match(regex, buf):
                        return True
            finally:
                f.close()
        finally:
            if local_file is not None:
                os.unlink(local_file)

        return False

    def _kernelFetchHelper(self, fetcher, guest, progresscb, kernelpath, initrdpath):
        # Simple helper for fetching kernel + initrd and performing
        # cleanup if neccessary
        kernel = fetcher.acquireFile(kernelpath, progresscb)
        args = ''

        if not fetcher.location.startswith("/"):
            args += "method=" + fetcher.location

        if guest.extraargs:
            args += guest.extraargs

        try:
            initrd = fetcher.acquireFile(initrdpath, progresscb)
            return kernel, initrd, args
        except:
            os.unlink(kernel)


class GenericDistro(Distro):
    """Generic distro store. Check well known paths for kernel locations
       as a last resort if we can't recognize any actual distro"""

    name = "Generic"
    os_type = "linux"
    uses_treeinfo = True

    _xen_paths = [ ("images/xen/vmlinuz",
                    "images/xen/initrd.img"),           # Fedora
                 ]
    _hvm_paths = [ ("images/pxeboot/vmlinuz",
                    "images/pxeboot/initrd.img"),       # Fedora
                 ]
    _iso_paths = [ "images/boot.iso",                   # RH/Fedora
                   "boot/boot.iso",                     # Suse
                   "current/images/netboot/mini.iso",   # Debian
                   "install/images/boot.iso",           # Mandriva
                 ]

    # Holds values to use when actually pulling down media
    _valid_kernel_path = None
    _valid_iso_path = None

    def isValidStore(self, fetcher, progresscb):
        if self._hasTreeinfo(fetcher, progresscb):
            # Use treeinfo to pull down media paths
            if self.type == "xen":
                typ = "xen"
            else:
                typ = self.treeinfo.get("general", "arch")
            kernelSection = "images-%s" % typ
            isoSection = "images-%s" % self.treeinfo.get("general", "arch")

            if self.treeinfo.has_section(kernelSection):
                self._valid_kernel_path = (self._getTreeinfoMedia("kernel"),
                                           self._getTreeinfoMedia("initrd"))
            if self.treeinfo.has_section(isoSection):
                self._valid_iso_path = self.treeinfo.get(isoSection, "boot.iso")

        if self.type == "xen":
            kern_list = self._xen_paths
        else:
            kern_list = self._hvm_paths

        # If validated media paths weren't found (no treeinfo), check against
        # list of media location paths.
        for kern, init in kern_list:
            if self._valid_kernel_path == None \
               and fetcher.hasFile(kern) and fetcher.hasFile(init):
                self._valid_kernel_path = (kern, init)
                break
        for iso in self._iso_paths:
            if self._valid_iso_path == None \
               and fetcher.hasFile(iso):
                self._valid_iso_path = iso
                break

        if self._valid_kernel_path or self._valid_iso_path:
            return True
        return False

    def acquireKernel(self, guest, fetcher, progresscb):
        if self._valid_kernel_path == None:
            raise ValueError(_("Could not find a kernel path for virt type "
                               "'%s'" % self.type))

        return self._kernelFetchHelper(fetcher, guest, progresscb,
                                       self._valid_kernel_path[0],
                                       self._valid_kernel_path[1])

    def acquireBootDisk(self, fetcher, progresscb):
        if self._valid_iso_path == None:
            raise ValueError(_("Could not find a boot iso path for this tree."))

        return fetcher.acquireFile(self._valid_iso_path, progresscb)


# Base image store for any Red Hat related distros which have
# a common layout
class RedHatDistro(Distro):

    name = "Red Hat"
    os_type = "linux"
    uses_treeinfo = True
    _boot_iso_paths   = [ "images/boot.iso" ]
    _hvm_kernel_paths = [ ("images/pxeboot/vmlinuz",
                           "images/pxeboot/initrd.img") ]
    _xen_kernel_paths = [ ("images/xen/vmlinuz",
                           "images/xen/initrd.img") ]

    def isValidStore(self, fetcher, progresscb):
        raise NotImplementedError


# Fedora distro check
class FedoraDistro(RedHatDistro):

    name = "Fedora"
    os_type = "linux"

    def isValidStore(self, fetcher, progresscb):
        if self._hasTreeinfo(fetcher, progresscb):
            m = re.match(".*Fedora.*", self.treeinfo.get("general", "family"))
            return (m != None)
        else:
            if fetcher.hasFile("Fedora"):
                logging.debug("Detected a Fedora distro")
                return True
            return False

# Red Hat Enterprise Linux distro check
class RHELDistro(RedHatDistro):

    name = "Red Hat Enterprise Linux"
    os_type = "linux"

    def isValidStore(self, fetcher, progresscb):
        if self._hasTreeinfo(fetcher, progresscb):
            m = re.match(".*Red Hat Enterprise Linux.*", self.treeinfo.get("general", "family"))
            return (m != None)
        else:
            # fall back to old code
            if fetcher.hasFile("Server"):
                logging.debug("Detected a RHEL 5 Server distro")
                return True
            if fetcher.hasFile("Client"):
                logging.debug("Detected a RHEL 5 Client distro")
                return True
            if fetcher.hasFile("RedHat"):
                logging.debug("Detected a RHEL 4 distro")
                return True
            return False

# CentOS distro check
class CentOSDistro(RedHatDistro):

    name = "CentOS"
    os_type = "linux"

    def isValidStore(self, fetcher, progresscb):
        if self._hasTreeinfo(fetcher, progresscb):
            m = re.match(".*CentOS.*", self.treeinfo.get("general", "family"))
            return (m != None)
        else:
            # fall back to old code
            if fetcher.hasFile("CentOS"):
                logging.debug("Detected a CentOS distro")
                return True
            return False

# Scientific Linux distro check
class SLDistro(RedHatDistro):

    name = "Scientific Linux"
    os_type = "linux"
    _boot_iso_paths = RedHatDistro._boot_iso_paths + [ "images/SL/boot.iso" ]
    _hvm_kernel_paths = RedHatDistro._hvm_kernel_paths + \
                        [ ("images/SL/pxeboot/vmlinuz",
                           "images/SL/pxeboot/initrd.img") ]

    def isValidStore(self, fetcher, progresscb):
        if self._hasTreeinfo(fetcher, progresscb):
            m = re.match(".*Scientific Linux.*",
                         self.treeinfo.get("general", "family"))
            return (m != None)
        else:
            if fetcher.hasFile("SL"):
                logging.debug("Detected a Scientific Linux distro")
                return True
            return False



# Suse  image store is harder - we fetch the kernel RPM and a helper
# RPM and then munge bits together to generate a initrd
class SuseDistro(Distro):

    name = "SUSE"
    os_type = "linux"
    _boot_iso_paths   = [ "boot/boot.iso" ]
    _hvm_kernel_paths = []
    _xen_kernel_paths = []

    def __init__(self, uri, vmtype=None, scratchdir=None, arch=None):
        Distro.__init__(self, uri, vmtype, scratchdir, arch)
        if re.match(r'i[4-9]86', arch):
            self.arch = 'i386'

        # Tested with Opensuse 10, 11, and sles 10
        self._hvm_kernel_paths += [ ("boot/%s/loader/linux" % self.arch,
                                     "boot/%s/loader/initrd" % self.arch) ]
        # Matches Opensuse > 10.2 and sles 10
        self._xen_kernel_paths += [ ("boot/%s/vmlinuz-xen" % self.arch,
                                     "boot/%s/initrd-xen" % self.arch) ]

    def isValidStore(self, fetcher, progresscb):
        # Suse distros always have a 'directory.yast' file in the top
        # level of install tree, which we use as the magic check
        if fetcher.hasFile("directory.yast"):
            logging.debug("Detected a Suse distro.")
            return True
        return False

    def acquireKernel(self, guest, fetcher, progresscb):
        # If installing a fullvirt guest
        if self.type is None or self.type == "hvm" or \
           fetcher.hasFile("boot/%s/vmlinuz-xen" % self.arch):
            return Distro.acquireKernel(self, guest, fetcher, progresscb)

        # For Opensuse <= 10.2, we need to perform some heinous stuff
        logging.debug("Trying Opensuse 10 PV rpm hacking")
        return self._findXenRPMS(fetcher, progresscb)


    def _findXenRPMS(self, fetcher, progresscb):
        kernelrpm = None
        installinitrdrpm = None
        filelist = None
        try:
            # There is no predictable filename for kernel/install-initrd RPMs
            # so we have to grok the filelist and find them
            filelist = fetcher.acquireFile("ls-lR.gz", progresscb)
            (kernelrpmname, initrdrpmname) = self._extractRPMNames(filelist)

            # Now fetch the two RPMs we want
            kernelrpm = fetcher.acquireFile(kernelrpmname, progresscb)
            installinitrdrpm = fetcher.acquireFile(initrdrpmname, progresscb)

            # Process the RPMs to extract the kernel & generate an initrd
            return self._buildKernelInitrd(fetcher, kernelrpm, installinitrdrpm, progresscb)
        finally:
            if filelist is not None:
                os.unlink(filelist)
            if kernelrpm is not None:
                os.unlink(kernelrpm)
            if installinitrdrpm is not None:
                os.unlink(installinitrdrpm)

    # We need to parse the ls-lR.gz file, looking for the kernel &
    # install-initrd RPM entries - capturing the directory they are
    # in and the version'd filename.
    def _extractRPMNames(self, filelist):
        filelistData = gzip.GzipFile(filelist, mode = "r")
        try:
            arches = [self.arch]
            # On i686 arch, we also look under i585 and i386 dirs
            # in case the RPM is built for a lesser arch. We also
            # need the PAE variant (for Fedora dom0 at least)
            #
            # XXX shouldn't hard code that dom0 is PAE
            if self.arch == "i386":
                arches.append("i586")
                arches.append("i686")
                kernelname = "kernel-xenpae"
            else:
                kernelname = "kernel-xen"

            installinitrdrpm = None
            kernelrpm = None
            dirname = None
            while 1:
                data = filelistData.readline()
                if not data:
                    break
                if dirname is None:
                    for arch in arches:
                        wantdir = "/suse/" + arch
                        if data == "." + wantdir + ":\n":
                            dirname = wantdir
                            break
                else:
                    if data == "\n":
                        dirname = None
                    else:
                        if data[:5] != "total":
                            filename = re.split("\s+", data)[8]

                            if filename[:14] == "install-initrd":
                                installinitrdrpm = dirname + "/" + filename
                            elif filename[:len(kernelname)] == kernelname:
                                kernelrpm = dirname + "/" + filename

            if kernelrpm is None:
                raise Exception(_("Unable to determine kernel RPM path"))
            if installinitrdrpm is None:
                raise Exception(_("Unable to determine install-initrd RPM path"))
            return (kernelrpm, installinitrdrpm)
        finally:
            filelistData.close()

    # We have a kernel RPM and a install-initrd RPM with a generic initrd in it
    # Now we have to merge the two together to build an initrd capable of
    # booting the installer.
    #
    # Yes, this is crazy ass stuff :-)
    def _buildKernelInitrd(self, fetcher, kernelrpm, installinitrdrpm, progresscb):
        progresscb.start(text=_("Building initrd"), size=11)
        progresscb.update(1)
        cpiodir = tempfile.mkdtemp(prefix="virtinstcpio.", dir=self.scratchdir)
        try:
            # Extract the kernel RPM contents
            os.mkdir(cpiodir + "/kernel")
            cmd = "cd " + cpiodir + "/kernel && (rpm2cpio " + kernelrpm + " | cpio --quiet -idm)"
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.update(2)

            # Determine the raw kernel version
            kernelinfo = None
            for f in os.listdir(cpiodir + "/kernel/boot"):
                if f.startswith("System.map-"):
                    kernelinfo = re.split("-", f)
            kernel_override = kernelinfo[1] + "-override-" + kernelinfo[3]
            kernel_version = kernelinfo[1] + "-" + kernelinfo[2] + "-" + kernelinfo[3]
            logging.debug("Got kernel version " + str(kernelinfo))

            # Build a list of all .ko files
            modpaths = {}
            for root, dummy, files in os.walk(cpiodir + "/kernel/lib/modules", topdown=False):
                for name in files:
                    if name.endswith(".ko"):
                        modpaths[name] = os.path.join(root, name)
            progresscb.update(3)

            # Extract the install-initrd RPM contents
            os.mkdir(cpiodir + "/installinitrd")
            cmd = "cd " + cpiodir + "/installinitrd && (rpm2cpio " + installinitrdrpm + " | cpio --quiet -idm)"
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.update(4)

            # Read in list of mods required for initrd
            modnames = []
            fn = open(cpiodir + "/installinitrd/usr/lib/install-initrd/" + kernelinfo[3] + "/module.list", "r")
            try:
                while 1:
                    line = fn.readline()
                    if not line:
                        break
                    line = line[:len(line)-1]
                    modnames.append(line)
            finally:
                fn.close()
            progresscb.update(5)

            # Uncompress the basic initrd
            cmd = "gunzip -c " + cpiodir + "/installinitrd/usr/lib/install-initrd/initrd-base.gz > " + cpiodir + "/initrd.img"
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.update(6)

            # Create temp tree to hold stuff we're adding to initrd
            moddir = cpiodir + "/initrd/lib/modules/" + kernel_override + "/initrd/"
            moddepdir = cpiodir + "/initrd/lib/modules/" + kernel_version
            os.makedirs(moddir)
            os.makedirs(moddepdir)
            os.symlink("../" + kernel_override, moddepdir + "/updates")
            os.symlink("lib/modules/" + kernel_override + "/initrd", cpiodir + "/initrd/modules")
            cmd = "cp " + cpiodir + "/installinitrd/usr/lib/install-initrd/" + kernelinfo[3] + "/module.config" + " " + moddir
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.update(7)

            # Copy modules we need into initrd staging dir
            for modname in modnames:
                if modpaths.has_key(modname):
                    src = modpaths[modname]
                    dst = moddir + "/" + modname
                    os.system("cp " + src + " " + dst)
            progresscb.update(8)

            # Run depmod across the staging area
            cmd = "depmod -a -b " + cpiodir + "/initrd -F " + cpiodir + "/kernel/boot/System.map-" + kernel_version + " " + kernel_version
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.update(9)

            # Add the extra modules to the basic initrd
            cmd = "cd " + cpiodir + "/initrd && ( find . | cpio --quiet -o -H newc -A -F " + cpiodir + "/initrd.img)"
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.update(10)

            # Compress the final initrd
            cmd = "gzip -f9N " + cpiodir + "/initrd.img"
            logging.debug("Running " + cmd)
            os.system(cmd)
            progresscb.end(11)

            # Save initrd & kernel to temp files for booting...
            initrdname = fetcher.saveTemp(open(cpiodir + "/initrd.img.gz", "r"), "initrd.img")
            logging.debug("Saved " + initrdname)
            try:
                kernelname = fetcher.saveTemp(open(cpiodir + "/kernel/boot/vmlinuz-" + kernel_version, "r"), "vmlinuz")
                logging.debug("Saved " + kernelname)
                return (kernelname, initrdname, "install=" + fetcher.location)
            except:
                os.unlink(initrdname)
        finally:
            #pass
            os.system("rm -rf " + cpiodir)


class DebianDistro(Distro):
    # ex. http://ftp.egr.msu.edu/debian/dists/sarge/main/installer-i386/
    # daily builds: http://people.debian.org/~joeyh/d-i/

    name = "Debian"
    os_type = "linux"

    def __init__(self, uri, vmtype=None, scratchdir=None, arch=None):
        Distro.__init__(self, uri, vmtype, scratchdir, arch)
        if uri.count("installer-i386"):
            self._treeArch = "i386"
        elif uri.count("installer-amd64"):
            self._treeArch = "amd64"
        else:
            self._treeArch = "i386"

        if re.match(r'i[4-9]86', arch):
            self.arch = 'i386'

        self._prefix = 'current/images'
        self._set_media_paths()

    def _set_media_paths(self):
        # Use self._prefix to set media paths
        self._boot_iso_paths   = [ "%s/netboot/mini.iso" % self._prefix ]
        hvmroot = "%s/netboot/debian-installer/%s/" % (self._prefix,
                                                       self._treeArch)
        xenroot = "%s/netboot/xen/" % self._prefix
        self._hvm_kernel_paths = [ (hvmroot + "linux", hvmroot + "initrd.gz") ]
        self._xen_kernel_paths = [ (xenroot + "vmlinuz",
                                    xenroot + "initrd.gz") ]

    def isValidStore(self, fetcher, progresscb):

        # For regular trees
        if fetcher.hasFile("%s/MANIFEST" % self._prefix):
            pass
        # For daily trees
        elif fetcher.hasFile("images/daily/MANIFEST"):
            self._prefix = "images/daily"
            self._set_media_paths()
        else:
            logging.debug("Doesn't look like a Debian distro.")
            return False

        filename = "%s/MANIFEST" % self._prefix

        if self._fetchAndMatchRegex(fetcher, progresscb, filename,
                                    ".*debian-installer.*"):
            logging.debug("Detected a Debian distro")
            return True

        return False


class UbuntuDistro(DebianDistro):

    name = "Ubuntu"
    os_type = "linux"

    def _set_media_paths(self):
        DebianDistro._set_media_paths(self)
        root = "%s/netboot/ubuntu-installer/%s/" % (self._prefix,
                                                    self._treeArch)
        self._hvm_kernel_paths = [ (root + "linux", root + "initrd.gz") ]
        self._xen_kernel_paths = []

    def isValidStore(self, fetcher, progresscb):
        # Don't support any paravirt installs
        if self.type is not None and self.type != "hvm":
            return False

        # For regular trees
        if not fetcher.hasFile("%s/MANIFEST" % self._prefix):
            return False

        if self._fetchAndMatchRegex(fetcher, progresscb,
                                    "%s/MANIFEST" % self._prefix,
                                    ".*ubuntu-installer.*"):
            logging.debug("Detected an Ubuntu distro")
            return True

        return False


class MandrivaDistro(Distro):
    # Ex. ftp://ftp.uwsg.indiana.edu/linux/mandrake/official/2007.1/x86_64/

    name = "Mandriva"
    os_type = "linux"
    _boot_iso_paths = [ "install/images/boot.iso" ]
    # Kernels for HVM: valid for releases 2007.1, 2008.*, 2009.0
    _hvm_kernel_paths = [ ("isolinux/alt0/vmlinuz", "isolinux/alt0/all.rdz")]
    _xen_kernel_paths = []

    def isValidStore(self, fetcher, progresscb):
        # Don't support any paravirt installs
        if self.type is not None and self.type != "hvm":
            return False

        # Mandriva websites / media appear to have a VERSION
        # file in top level which we can use as our 'magic'
        # check for validity
        if self._fetchAndMatchRegex(fetcher, progresscb, "VERSION",
                                    ".*Mandriva.*"):
            logging.debug("Detected a Mandriva distro")
            return True

        return False

# Solaris and OpenSolaris distros
class SunDistro(Distro):

    name = "Solaris"
    os_type = "solaris"

    def isValidStore(self, fetcher, progresscb):
        """Determine if uri points to a tree of the store's distro"""
        raise NotImplementedError

    def acquireBootDisk(self, fetcher, progresscb):
        return fetcher.acquireFile("images/solarisdvd.iso", progresscb)

    def process_extra_args(self, argstr):
        """Collect additional arguments."""
        if not argstr:
            return (None, None, None, None)

        kopts = ''
        kargs = ''
        smfargs = ''
        Bargs = ''

        args = argstr.split()
        i = 0
        while i < len(args):
            exarg = args[i]
            if exarg == '-B':
                i += 1
                if i == len(args):
                    continue

                if not Bargs:
                    Bargs = args[i]
                else:
                    Bargs = ','.join([Bargs, args[i]])
        
            elif exarg == '-m':
                i += 1
                if i == len(args):
                    continue
                smfargs = args[i]
            elif exarg.startswith('-'):
                if kopts is None:
                    kopts = exarg[1:]
                else:
                    kopts = kopts + exarg[1:]
            else:
                if kargs is None:
                    kargs = exarg
                else:
                    kargs = kargs + ' ' + exarg
            i += 1

        return kopts, kargs, smfargs, Bargs

class SolarisDistro(SunDistro):
    kernelpath = 'boot/platform/i86xpv/kernel/unix'
    initrdpath = 'boot/x86.miniroot'

    def isValidStore(self, fetcher, progresscb):
        if fetcher.hasFile(self.kernelpath):
            logging.debug('Detected Solaris')
            return True
        return False

    def install_args(self, guest):
        """Construct kernel cmdline args for the installer, consisting of:
           the pathname of the kernel (32/64) to load, kernel options
           and args, and '-B' boot properties."""

        # XXX: ignoring smfargs for the time being
        (kopts, kargs, smfargs, kbargs) = \
            self.process_extra_args(guest.extraargs)

        args = [ '' ]
        if kopts:
            args += [ '-%s' % kopts ]
        if kbargs:
            args += [ '-B', kbargs ]

        netmask = ''
        # Yuck. Non-default netmasks require this option to be passed.
        # It's distinctly not-trivial to work out the netmask to be used
        # automatically.
        if kargs:
            for karg in kargs.split():
                if karg.startswith('subnet-mask'):
                    netmask = karg.split('=')[1]
                else:
                    args += [ kargs ]

        iargs = ''
        if not guest.graphics['enabled']:
            iargs += 'nowin '

        if guest.location.startswith('nfs:'):
            try:
                guestIP = socket.gethostbyaddr(guest.name)[2][0]
            except:
                iargs += ' dhcp'
            else:
                iserver = guest.location.split(':')[1]
                ipath = guest.location.split(':')[2]
                iserverIP = socket.gethostbyaddr(iserver)[2][0]
                iargs += ' -B install_media=' + iserverIP + ':' + ipath
                iargs += ',host-ip=' + guestIP
                if netmask:
                    iargs += ',subnet-mask=%s' % netmask
                droute = _util.default_route(guest.nics[0].bridge)
                if droute:
                    iargs += ',router-ip=' + droute
                if guest.nics[0].macaddr:
                    en = guest.nics[0].macaddr.split(':')
                    for i in range(len(en)):
                        # remove leading '0' from mac address element
                        if len(en[i]) > 1 and en[i][0] == '0':
                            en[i] = en[i][1]
                    boot_mac = ':'.join(en)
                    iargs += ',boot-mac=' + boot_mac
        else:
            iargs += '-B install_media=cdrom'

        args += [ '-', iargs ]
        return ' '.join(args)

    def acquireKernel(self, guest, fetcher, progresscb):

        try:
            kernel = fetcher.acquireFile(self.kernelpath, progresscb)
        except:
            raise RuntimeError("Solaris PV kernel not found at %s" %
                self.kernelpath)

        # strip boot from the kernel path
        kpath = self.kernelpath.split('/')[1:]
        args = "/" + "/".join(kpath) + self.install_args(guest)

        try:
            initrd = fetcher.acquireFile(self.initrdpath, progresscb)
            return (kernel, initrd, args)
        except:
            os.unlink(kernel)
            raise RuntimeError(_("Solaris miniroot not found at %s") %
                self.initrdpath)

class OpenSolarisDistro(SunDistro):
    kernelpath = "platform/i86xpv/kernel/unix"
    initrdpath = "boot/x86.microroot"

    def isValidStore(self, fetcher, progresscb):
        if fetcher.hasFile(self.kernelpath):
            logging.debug("Detected OpenSolaris")
            return True
        return False

    def install_args(self, guest):
        """Construct kernel cmdline args for the installer, consisting of:
           the pathname of the kernel (32/64) to load, kernel options
           and args, and '-B' boot properties."""

        # XXX: ignoring smfargs and kargs for the time being
        (kopts, kargs, smfargs, kbargs) = \
            self.process_extra_args(guest.extraargs)

        args = ''
        if kopts:
            args += '-' + kopts
        if kbargs:
            args += ' -B ' + kbargs

        return args

    def acquireKernel(self, guest, fetcher, progresscb):

        try:
            kernel = fetcher.acquireFile(self.kernelpath, progresscb)
        except:
            raise RuntimeError(_("OpenSolaris PV kernel not found at %s") %
                self.kernelpath)

        args = "/" + self.kernelpath + self.install_args(guest)

        try:
            initrd = fetcher.acquireFile(self.initrdpath, progresscb)
            return (kernel, initrd, args)
        except:
            os.unlink(kernel)
            raise RuntimeError(_("OpenSolaris microroot not found at %s") %
                self.initrdpath)
