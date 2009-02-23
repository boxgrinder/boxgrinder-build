#!/bin/sh

FILES="setup.py tests/ virt-install virt-image virt-clone virt-convert virtinst/ virtconv virtconv/parsers/*.py"

# Exceptions: deliberately ignore these regex

# False positive: using the private excepthook is needed for custom exception
# handler
EXCEPTHOOK='__excepthook__'

# Following functions are in the public api which have argument names that
# override builtin 'type'.
BUILTIN_TYPE="(StoragePool.__init__|randomMAC|Capabilities.guestForOSType|acquireKernel|acquireBootDisk|DistroInstaller.__init__|PXEInstaller.__init__|Guest.list_os_variants|Guest.get_os_type_label|Guest.get_os_variant_label|FullVirtGuest.__init__|VirtualNetworkInterface.__init__|VirtualGraphics.__init__|Installer.__init__|Guest.__init__|LiveCDInstaller.__init__|ParaVirtGuest.__init__|VirtOptionParser.print_help|get_max_vcpus|setupLogging.exception_log|VirtualDisk.__init__|disk.__init__|netdev.__init__)"
BTYPE_TYPE="${BUILTIN_TYPE}.*Redefining built-in 'type'"

# Following functions are in the public api which have argument names that
# override builtin 'str'.
BUILTIN_STR="(xml_escape)"
BTYPE_STR="${BUILTIN_STR}.*Redefining built-in 'str'"

# Following functions are in the public api which have argument names that
# override builtin 'str'.
BUILTIN_FILE="(VirtOptionParser.print_help)"
BTYPE_FILE="${BUILTIN_FILE}.*Redefining built-in 'file'"

# Using os._exit is required in forked processes
USE_OF__EXIT="member _exit"

# False positive: we install the _ function in the builtin namespace, but
# pylint doesn't pick it up
UNDEF_GETTEXT="Undefined variable '_'"

# Public api error
VD_MISMATCHED_ARGS="VirtualDisk.get_xml_config.*Arguments number differs"

# urltest needs access to protected members for testing purposes
URLTEST_ACCESS="TestURLFetch.*Access to a protected member"

# Libvirt connect() method is broken for getting an objects connection, this
# workaround is required for now
ACCESS__CONN="Access to a protected member _conn"

# There isn't a clean API way to access this functions from the API, but
# they provide info that is needed. These need need to be fixed.
PROT_MEM_BUGS="protected member (_get_osblob|_prepare_install|_create_devices|_install_disks)"

# Scattered examples of legitimately unused arguments
UNUSED_ARGS="SuseDistro.isValidStore.*Unused argument 'progresscb'|LiveCDInstaller.prepare.*Unused argument|ImageInstaller.prepare.*Unused argument|post_install_check.*Unused argument 'guest'|Guest.__init__.*Unused argument 'type'"

DMSG=""
addmsg() {
    DMSG="${DMSG},$1"
    }

DCHECKERS=""
addchecker() {
    DCHECKERS="${DCHECKERS},$1"
}

# Disabled Messages:
addmsg "C0103"  # C0103: Name doesn't match some style regex
addmsg "C0111"  # C0111: No docstring
addmsg "C0301"  # C0301: Line too long
addmsg "C0302"  # C0302: Too many lines in module
addmsg "W0105"  # W0105: String statement has no effect
addmsg "W0141"  # W0141: Complaining about 'map' and 'filter'
addmsg "W0142"  # W0142: Use of * or **
addmsg "W0201"  # W0201: Defined outside __init__
addmsg "W0403"  # W0403: Relative imports
addmsg "W0511"  # W0511: FIXME and XXX: messages (useful in the future)
addmsg "W0603"  # W0603: Using the global statement
addmsg "W0702"  # W0702: No exception type specified
addmsg "W0703"  # W0703: Catch 'Exception'
addmsg "W0704"  # W0704: Exception doesn't do anything
addmsg "C0322"  # C0322: *Operator not preceded by a space*
addmsg "C0323"  # C0323: *Operator not followed by a space*
addmsg "C0324"  # C0324: *Comma not followed by a space*
addmsg "R0201"  # R0201: Method could be a function

# Disabled Checkers:
addchecker "Design"         # Things like "Too many func arguments",
                            #             "Too man public methods"
addchecker "Similarities"   # Finds duplicate code (enable this later?)

AWK=awk
[ `uname -s` = 'SunOS' ] && AWK=nawk

pylint --ignore=coverage.py, $FILES \
  --reports=n \
  --output-format=colorized \
  --dummy-variables-rgx="dummy|ignore*" \
  --disable-msg=${DMSG} \
  --disable-checker=${DCHECKERS} | \
  egrep -ve "$EXCEPTHOOK" \
        -ve "$BTYPE_TYPE" \
        -ve "$BTYPE_FILE" \
        -ve "$BTYPE_STR" \
        -ve "$USE_OF__EXIT" \
        -ve "$UNDEF_GETTEXT" \
        -ve "$VD_MISMATCHED_ARGS" \
        -ve "$ACCESS__CONN" \
        -ve "$URLTEST_ACCESS" \
        -ve "$UNUSED_ARGS" \
        -ve "$PROT_MEM_BUGS" | \
  $AWK '\
# Strip out any "*** Module name" lines if we dont list any errors for them
BEGIN { found=0; cur_line="" }
{
    if (found == 1) {
        if ( /\*\*\*/ ) {
            prev_line = $0
        } else {
            print prev_line
            print $0
            found = 0
        }
    } else if ( /\*\*\*/ ) {
        found = 1
        prev_line = $0
    } else {
        print $0
    }
}'
