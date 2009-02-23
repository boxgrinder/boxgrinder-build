#
# Utility functions for the command line drivers
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

import os, sys
import logging
import logging.handlers
import locale
from optparse import OptionValueError, OptionParser

import libvirt
import _util
from virtinst import CapabilitiesParser, VirtualNetworkInterface, \
                     VirtualGraphics, VirtualAudio, User
from virtinst import _virtinst as _

MIN_RAM = 64
force = False
doprompt = True

class VirtOptionParser(OptionParser):
    '''Subclass to get print_help to work properly with non-ascii text'''

    def _get_encoding(self, f):
        encoding = getattr(f, "encoding", None)
        if not encoding:
            (dummy, encoding) = locale.getlocale()
        return encoding

    def print_help(self, file=None):
        if file is None:
            file = sys.stdout
        encoding = self._get_encoding(file)
        file.write(self.format_help().encode(encoding, "replace"))

#
# Setup helpers
#

def setupLogging(appname, debug=False):
    # set up logging
    vi_dir = os.path.expanduser("~/.virtinst")
    if not os.access(vi_dir,os.W_OK):
        try:
            os.mkdir(vi_dir)
        except IOError, e:
            raise RuntimeError, "Could not create %d directory: " % vi_dir, e

    dateFormat = "%a, %d %b %Y %H:%M:%S"
    fileFormat = "[%(asctime)s " + appname + " %(process)d] %(levelname)s (%(module)s:%(lineno)d) %(message)s"
    streamDebugFormat = "%(asctime)s %(levelname)-8s %(message)s"
    streamErrorFormat = "%(levelname)-8s %(message)s"
    filename = os.path.join(vi_dir, appname + ".log")

    rootLogger = logging.getLogger()
    rootLogger.setLevel(logging.DEBUG)
    fileHandler = logging.handlers.RotatingFileHandler(filename, "a",
                                                       1024*1024, 5)

    fileHandler.setFormatter(logging.Formatter(fileFormat,
                                               dateFormat))
    rootLogger.addHandler(fileHandler)

    streamHandler = logging.StreamHandler(sys.stderr)
    if debug:
        streamHandler.setLevel(logging.DEBUG)
        streamHandler.setFormatter(logging.Formatter(streamDebugFormat,
                                                     dateFormat))
    else:
        streamHandler.setLevel(logging.ERROR)
        streamHandler.setFormatter(logging.Formatter(streamErrorFormat))
    rootLogger.addHandler(streamHandler)

    # Register libvirt handler
    def libvirt_callback(ignore, err):
        if err[3] != libvirt.VIR_ERR_ERROR:
            # Don't log libvirt errors: global error handler will do that
            logging.warn("Non-error from libvirt: '%s'" % err[2])
    libvirt.registerErrorHandler(f=libvirt_callback, ctx=None)

    # Register python error handler to log exceptions
    def exception_log(type, val, tb):
        import traceback
        s = traceback.format_exception(type, val, tb)
        logging.exception("".join(s))
        sys.__excepthook__(type, val, tb)
    sys.excepthook = exception_log

def fail(msg):
    """Convenience function when failing in cli app"""
    logging.error(msg)
    import traceback
    tb = "".join(traceback.format_exc()).strip()
    if tb != "None":
        logging.debug(tb)
    sys.exit(1)

def nice_exit():
    print _("Exiting at user request.")
    sys.exit(0)

def getConnection(connect):
    if not User.current().has_priv(User.PRIV_CREATE_DOMAIN, connect):
        fail(_("Must be root to create Xen guests"))
    if connect is None:
        fail(_("Could not find usable default libvirt connection."))

    logging.debug("Using libvirt URI connect '%s'" % connect)
    return libvirt.open(connect)

#
# Prompting
#

def set_force(val=True):
    global force
    force = val

def set_prompt(prompt=True):
    # Set whether we allow prompts, or fail if a prompt pops up
    global doprompt
    doprompt = prompt

def prompt_for_input(prompt = "", val = None):
    if val is not None:
        return val
    if force:
        fail(_("Force flag is set but input was required. "
               "Prompt was: %s" % prompt))
    if not doprompt:
        fail(_("Prompting disabled, but input was requested. "
               "Prompt was: %s" % prompt))
    print prompt + " ",
    return sys.stdin.readline().strip()

def yes_or_no(s):
    s = s.lower()
    if s in ("y", "yes", "1", "true", "t"):
        return True
    elif s in ("n", "no", "0", "false", "f"):
        return False
    raise ValueError, "A yes or no response is required"

def prompt_for_yes_or_no(prompt):
    """catches yes_or_no errors and ensures a valid bool return"""
    if force:
        logging.debug("Forcing return value of True to prompt '%s'")
        return True

    if not doprompt:
        fail(_("Prompting disabled, but yes/no was requested. "
               "Try --force to force 'yes' for such prompts. "
               "Prompt was: %s" % prompt))

    while 1:
        inp = prompt_for_input(prompt, None)
        try:
            res = yes_or_no(inp)
            break
        except ValueError, e:
            print _("ERROR: "), e
            continue
    return res

#
# Ask for attributes
#

def get_name(name, guest):
    if name is None:
        fail(_("A name is required for the virtual machine."))
    try:
        guest.name = name
    except ValueError, e:
        fail(e)

def get_memory(memory, guest):
    if memory is None:
        fail(_("Memory amount is required for the virtual machine."))
    if memory < MIN_RAM:
        fail(_("Installs currently require %d megs of RAM.") % MIN_RAM)
    try:
        guest.memory = memory
    except ValueError, e:
        fail(e)

def get_uuid(uuid, guest):
    if uuid:
        try:
            guest.uuid = uuid
        except ValueError, e:
            fail(e)

def get_vcpus(vcpus, check_cpu, guest, conn):

    if check_cpu:
        hostinfo = conn.getInfo()
        cpu_num = hostinfo[4] * hostinfo[5] * hostinfo[6] * hostinfo[7]
        if vcpus <= cpu_num:
            pass
        elif not prompt_for_yes_or_no(_("You have asked for more virtual CPUs (%d) than there are physical CPUs (%d) on the host. This will work, but performance will be poor. Are you sure? (yes or no)") % (vcpus, cpu_num)):
            nice_exit()

    if vcpus is not None:
        try:
            guest.vcpus = vcpus
        except ValueError, e:
            fail(e)

def get_cpuset(cpuset, mem, guest, conn):
    if cpuset and cpuset != "auto":
        guest.cpuset = cpuset
    elif cpuset == "auto":
        caps = CapabilitiesParser.parse(conn.getCapabilities())
        if caps.host.topology is None:
            logging.debug("No topology section in caps xml. Skipping cpuset")
            return

        cells = caps.host.topology.cells
        if len(cells) <= 1:
            logging.debug("Capabilities only show <= 1 cell. Not NUMA capable")
            return

        cell_mem = conn.getCellsFreeMemory(0, len(cells))
        cell_id = -1
        mem = mem * 1024
        for i in range(len(cells)):
            if cell_mem[i] > mem and len(cells[i].cpus) != 0:
                # Find smallest cell that fits
                if cell_id < 0 or cell_mem[i] < cell_mem[cell_id]:
                    cell_id = i
        if cell_id < 0:
            logging.debug("Could not find any usable NUMA cell/cpu combinations. Not setting cpuset.")
            return

        # Build cpuset
        cpustr = ""
        for cpu in cells[cell_id].cpus:
            if cpustr != "":
                cpustr += ","
            cpustr += str(cpu.id)
        logging.debug("Auto cpuset is: %s" % cpustr)
        guest.cpuset = cpustr
    return

def get_network(mac, network, guest):
    if mac == "RANDOM":
        mac = None
    if network == "user":
        n = VirtualNetworkInterface(mac, type="user", conn=guest.conn)
    elif network[0:6] == "bridge":
        n = VirtualNetworkInterface(mac, type="bridge", bridge=network[7:],
                                    conn=guest.conn)
    elif network[0:7] == "network":
        n = VirtualNetworkInterface(mac, type="network", network=network[8:],
                                    conn=guest.conn)
    else:
        fail(_("Unknown network type ") + network)
    guest.nics.append(n)

def digest_networks(conn, macs, bridges, networks, nics = 0):
    def listify(l):
        if l is None:
            return []
        elif type(l) != list:
            return [ l ]
        else:
            return l

    macs     = listify(macs)
    bridges  = listify(bridges)
    networks = listify(networks)

    if bridges and networks:
        fail(_("Cannot mix both --bridge and --network arguments"))

    if bridges:
        networks = map(lambda b: "bridge:" + b, bridges)
    
    # With just one mac, create a default network if one is not
    # specified.
    if len(macs) == 1 and len(networks) == 0:
        if User.current().has_priv(User.PRIV_CREATE_NETWORK, conn.getURI()):
            net = _util.default_network(conn)
            networks.append(net[0] + ":" + net[1])
        else:
            networks.append("user")

    # ensure we have less macs then networks. Auto fill in the remaining
    # macs       
    if len(macs) > len(networks):
        fail(_("Need to pass equal numbers of networks & mac addresses"))
    else:
        for dummy in range (len(macs),len(networks)):
            macs.append(None)
            
    
    # Create extra networks up to the number of nics requested 
    if len(macs) < nics:
        for dummy in range(len(macs),nics):
            if User.current().has_priv(User.PRIV_CREATE_NETWORK, conn.getURI()):
                net = _util.default_network(conn)
                networks.append(net[0] + ":" + net[1])
            else:
                networks.append("user")
            macs.append(None)
            
    return (macs, networks)

def get_graphics(vnc, vncport, nographics, sdl, keymap, guest):
    if (vnc and nographics) or \
       (vnc and sdl) or \
       (sdl and nographics):
        raise ValueError, _("Can't specify more than one of VNC, SDL, "
                            "or --nographics")

    if not (vnc or nographics or sdl):
        if "DISPLAY" in os.environ.keys():
            logging.debug("DISPLAY is set: graphics defaulting to VNC.")
            vnc = True
        else:
            logging.debug("DISPLAY is not set: defaulting to nographics.")
            nographics = True

    if nographics is not None:
        guest.graphics_dev = None
        return
    if sdl is not None:
        guest.graphics_dev = VirtualGraphics(type=VirtualGraphics.TYPE_SDL)
        return
    if vnc is not None:
        guest.graphics_dev = VirtualGraphics(type=VirtualGraphics.TYPE_VNC)
    if vncport:
        guest.graphics_dev.port = vncport
    if keymap:
        guest.graphics_dev.keymap = keymap

def get_sound(sound, guest):

    # Sound is just a boolean value, so just specify a default of 'es1370'
    # model since this should provide audio out of the box for most modern
    # distros
    if sound:
        guest.sound_devs.append(VirtualAudio(model="es1370"))

### Option parsing
def check_before_store(option, opt_str, value, parser):
    if len(value) == 0:
        raise OptionValueError, _("%s option requires an argument") %opt_str
    setattr(parser.values, option.dest, value)

def check_before_append(option, opt_str, value, parser):
    if len(value) == 0:
        raise OptionValueError, _("%s option requires an argument") %opt_str
    parser.values.ensure_value(option.dest, []).append(value)

