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

import virtinst.DistroManager as DistroManager
from virtinst.OSDistro import FedoraDistro
from virtinst.OSDistro import SuseDistro
from virtinst.OSDistro import DebianDistro
from virtinst.OSDistro import CentOSDistro
from virtinst.OSDistro import SLDistro
from virtinst.OSDistro import UbuntuDistro
from virtinst.OSDistro import MandrivaDistro

import unittest
import logging
import re
import urlgrabber.progress
import tests

# Filters for including/excluding certain distros.
MATCH_FILTER=".*"

# GeoIP/managed URLs
FEDORA_BASEURL = "http://download.fedoraproject.org/pub/fedora/linux/releases/%s/Fedora/%s/os/"
FEDORA_RAWHIDE_BASEURL = "http://download.fedoraproject.org/pub/fedora/linux/development/%s/os"
OPENSUSE_BASEURL = "http://download.opensuse.org/distribution/%s/repo/oss/"

# ISO Code specific URLs
UBUNTU_BASEURL="http://us.archive.ubuntu.com/ubuntu/dists/%s/main/installer-%s"
DEBIAN_BASEURL = "http://ftp.us.debian.org/debian/dists/%s/main/installer-%s/"

# Static URLs
CURCENTOS_BASEURL = "http://ftp.linux.ncsu.edu/pub/CentOS/%s/os/%s/"
OLDCENTOS_BASEURL = "http://vault.centos.org/%s/os/%s"
MANDRIVA_BASEURL = "ftp://ftp.uwsg.indiana.edu/linux/mandrake/official/%s/%s/"
SCIENTIFIC_BASEURL = "http://ftp.scientificlinux.org/linux/scientific/%s/%s/"

# Regex matching distro names that don't have xen kernels.
NOXEN_FILTER=".*ubuntu.*|.*etch.*|.*mandriva.*|.*lenny-64.*|.*centos-4.0.*|.*scientific-4.0.*"

# Doesn't appear to be a simple boot iso in newer suse trees
NOBOOTISO_FILTER=".*opensuse11.*|.*opensuse10.3.*"

# Opensuse < 10.3 (and some sles) require crazy rpm hacking to get a bootable
# kernel. We expect failure in this case since our test harness doesn't
# actually fetch anything
EXPECT_XEN_FAIL=".*opensuse10.2.*"

# Return the expected Distro class for the passed distro label
def distroClass(distname):
    if re.match(r".*fedora.*", distname):
        return FedoraDistro
    elif re.match(r".*suse.*", distname):
        return SuseDistro
    elif re.match(r".*debian.*", distname):
        return DebianDistro
    elif re.match(r".*centos.*", distname):
        return CentOSDistro
    elif re.match(r".*ubuntu.*", distname):
        return UbuntuDistro
    elif re.match(r".*mandriva.*", distname):
        return MandrivaDistro
    elif re.match(r".*scientific.*", distname):
        return SLDistro
    raise RuntimeError("distroClass: no distro registered for '%s'" % distname)

# Dictionary with all the test data
urls = {

    # Fedora Distros
    "fedora7" : {
        'i386'  : FEDORA_BASEURL % ("7", "i386"),
        'x86_64': FEDORA_BASEURL % ("7", "x86_64")
    },
    "fedora8" : {
        'i386'  : FEDORA_BASEURL % ("8", "i386"),
        'x86_64': FEDORA_BASEURL % ("8", "x86_64")
    },
    "fedora9" : {
        'i386'  : FEDORA_BASEURL % ("9", "i386"),
        'x86_64': FEDORA_BASEURL % ("9", "x86_64")
    },
    #"fedora10" : {
    #    'i386'  : FEDORA_BASEURL % ("10", "i386")
    #    'x86_64': FEDORA_BASEURL % ("10", "x86_64")
    #},
    "fedora-rawhide" : {
        'i386'  : FEDORA_RAWHIDE_BASEURL % ("i386"),
        'x86_64': FEDORA_RAWHIDE_BASEURL % ("x86_64")
    },

    # SUSE Distros
    "opensuse10.2" : {
        'i386'  : OPENSUSE_BASEURL % ("10.2"),
        'x86_64': OPENSUSE_BASEURL % ("10.2")
    },
    "opensuse10.3" : {
        'i386'  : OPENSUSE_BASEURL % ("10.3"),
        'x86_64': OPENSUSE_BASEURL % ("10.3")
    },
    "opensuse11" : {
        'i386'  : OPENSUSE_BASEURL % ("11.0"),
        'x86_64': OPENSUSE_BASEURL % ("11.0")
    },

    # Debian Distros
    "debian-etch" : {
        'i386' : DEBIAN_BASEURL % ("etch", "i386"),
        'x86_64': DEBIAN_BASEURL % ("etch", "amd64")
    },
    "debian-lenny-32" : {
        'i386' : DEBIAN_BASEURL % ("lenny", "i386"),
    },
    "debian-lenny-64" : {
        'x86_64': DEBIAN_BASEURL % ("lenny", "amd64")
    },
    "debian-daily" : {
        'i386' : "http://people.debian.org/~joeyh/d-i/",
    },

    # CentOS Distros
    "centos-5-latest" : {
        'i386' : CURCENTOS_BASEURL % ("5", "i386"),
        'x86_64' : CURCENTOS_BASEURL % ("5", "x86_64"),
    },
    "centos-4-latest" : {
        'i386' : CURCENTOS_BASEURL % ("4", "i386"),
        'x86_64' : CURCENTOS_BASEURL % ("4", "x86_64"),
    },
    "centos-5.0" : {
        'i386' : OLDCENTOS_BASEURL % ("5.0", "i386"),
        'x86_64' : OLDCENTOS_BASEURL % ("5.0", "x86_64"),
    },
    "centos-4.0" : {
        'i386' : OLDCENTOS_BASEURL % ("4.0", "i386"),
        'x86_64' : OLDCENTOS_BASEURL % ("4.0", "x86_64"),
    },

    # Scientific Linux
    "scientific-5.2" : {
        'i386'  : SCIENTIFIC_BASEURL % ("52", "i386"),
        'x86_64': SCIENTIFIC_BASEURL % ("52", "x86_64"),
    },
    "scientific-5.0" : {
        'i386'  : SCIENTIFIC_BASEURL % ("50", "i386"),
        'x86_64': SCIENTIFIC_BASEURL % ("50", "x86_64"),
    },
    "scientific-4.7" : {
        'i386'  : SCIENTIFIC_BASEURL % ("47", "i386"),
        'x86_64': SCIENTIFIC_BASEURL % ("47", "x86_64"),
    },
    "scientific-4.0" : {
        'i386'  : SCIENTIFIC_BASEURL % ("40", "i386"),
        'x86_64': SCIENTIFIC_BASEURL % ("40", "x86_64"),
    },

    # Ubuntu
    "ubuntu-gutsy" : {
        'i386': UBUNTU_BASEURL % ("gutsy", "i386"),
        'x86_64': UBUNTU_BASEURL % ("gutsy", "amd64"),
    },
    "ubuntu-hardy" : {
        'i386': UBUNTU_BASEURL % ("hardy", "i386"),
        'x86_64': UBUNTU_BASEURL % ("hardy", "amd64"),
    },
    "ubuntu-intrepid" : {
        'i386': UBUNTU_BASEURL % ("intrepid", "i386"),
        'x86_64': UBUNTU_BASEURL % ("intrepid", "amd64"),
    },

    # Mandriva
    "mandriva-2007.1" : {
        'i386': MANDRIVA_BASEURL % ("2007.1", "i586"),
        'x86_64': MANDRIVA_BASEURL % ("2007.1", "x86_64"),
    },
    "mandriva-2008.1" : {
        'i386': MANDRIVA_BASEURL % ("2008.1", "i586"),
        'x86_64': MANDRIVA_BASEURL % ("2008.1", "x86_64"),
    },
    "mandriva-2009.0" : {
        'i386': MANDRIVA_BASEURL % ("2009.0", "i586"),
        'x86_64': MANDRIVA_BASEURL % ("2009.0", "x86_64"),
    },

}

class TestURLFetch(unittest.TestCase):

    def _fetchComparison(self, distname, url, arch):
        logging.debug("\nDistro='%s' arch='%s' url=%s" % \
                      (distname, arch, url))

        check_xen = True
        if re.match(r"%s" % NOXEN_FILTER, distname):
            check_xen = False

        meter=None
        if tests.debug:
            meter = urlgrabber.progress.TextMeter()
        fetcher = DistroManager._fetcherForURI(url, "/tmp")

        try:
            fetcher.prepareLocation()
        except Exception, e:
            logging.error("%s-%s: Couldn't access url %s: %s. Skipping." % \
                          (distname, arch, fetcher.location, str(e)))
            return

        hvmstore = DistroManager._storeForDistro(fetcher=fetcher, baseuri=url,
                                                 progresscb=meter, typ="hvm",
                                                 arch=arch)
        if check_xen:
            xenstore = DistroManager._storeForDistro(fetcher=fetcher,
                                                     baseuri=url,
                                                     progresscb=meter,
                                                     typ="xen",
                                                     arch=arch)
        else:
            xenstore = None

        exp_store = distroClass(distname)
        for s in [hvmstore, xenstore]:
            if s and not isinstance(s, exp_store):
                logging.error("(%s): expected store %s, was %s" % \
                              (distname, exp_store, s))
                self.fail()

        def fakeAcquireFile(filename, ignore=None):
            logging.debug("Fake acquiring %s" % filename)
            return fetcher.hasFile(filename)

        # Replace acquireFile with hasFile, so we don't actually have to fetch
        # 1000 kernels
        fetcher.acquireFile = fakeAcquireFile

        # Fetch boot iso
        try:
            if re.match(r"%s" % NOBOOTISO_FILTER, distname):
                logging.debug("Known lack of boot.iso in %s tree. Skipping." \
                              % distname)
            else:
                boot = hvmstore.acquireBootDisk(fetcher, meter)
                logging.debug("acquireBootDisk: %s" % str(boot))

                if boot != True:
                    raise RuntimeError("Didn't fetch any boot iso.")
        except Exception, e:
            logging.error("%s-%s: bootdisk fetching: %s" % (distname, arch,
                                                            str(e)))
            self.fail()

        # Fetch regular kernel
        try:
            kern = hvmstore.acquireKernel(fetcher, meter)
            logging.debug("acquireKernel (hvm): %s" % str(kern))

            if kern[0] is not True or kern[1] is not True:
                raise RuntimeError("Didn't fetch any hvm kernel.")
        except Exception, e:
            logging.error("%s-%s: hvm kernel fetching: %s" % (distname, arch,
                                                              str(e)))
            self.fail()

        # Fetch xen kernel
        try:
            if xenstore and check_xen:
                kern = xenstore.acquireKernel(fetcher, meter)
                logging.debug("acquireKernel (xen): %s" % str(kern))

                if kern[0] is not True or kern[1] is not True:
                    raise RuntimeError("Didn't fetch any xen kernel.")
            else:
                logging.debug("acquireKernel (xen): Hardcoded skipping.")
        except Exception, e:
            if re.match(r"%s" % EXPECT_XEN_FAIL, distname):
                logging.debug("%s: anticipated xen failure." % distname)
            else:
                logging.error("%s-%s: xen kernel fetching: %s" % (distname,
                                                                  arch,
                                                                  str(e)))
                self.fail()


    def testURLFetch(self):
        keys = urls.keys()
        keys.sort()
        assertions = 0
        for label in keys:
            if MATCH_FILTER and not re.match(r"%s" % MATCH_FILTER, label):
                logging.debug("Excluding '%s' from exclude filter." % label)
                continue
            for arch, url in urls[label].items():
                try:
                    self._fetchComparison(label, url, arch)
                except AssertionError:
                    assertions += 1

        if assertions != 0:
            raise AssertionError("Found %d errors in URL suite." % assertions)
