##
## Blatantly borrowed from the SRPM at
##
##  http://www.poolshark.org/src/dkms-open-vm-tools/dkms-open-vm-tools-0-1.2008.10.10.fc10.src.rpm
##

%define tname open-vm-tools
%define builddate 2009.02.18
%define buildver 148847

Name:      dkms-open-vm-tools
Version:   0
Release:   1.%{builddate}%{?dist}
Summary:   VMware Tools
Group:     Applications/Multimedia
License:   LGPLv2+
URL:       http://open-vm-tools.sourceforge.net/
Source0:   http://downloads.sourceforge.net/open-vm-tools/open-vm-tools-2009.02.18-148847.tar.gz
Source1:   vmware-guest.init
BuildRoot: %{_tmppath}/%{name}-%{builddate}-%{release}-root-%(%{__id_u} -n)

ExclusiveArch: i386 i586 i686 x86_64

BuildRequires: libdnet-devel
BuildRequires: libdnet
BuildRequires: libicu-devel
BuildRequires: glib2-devel

Requires(post):    dkms gcc desktop-file-utils
Requires(preun):   dkms gcc
Requires(postun) : desktop-file-utils

%description
The open-vm-tools are a subset of the VMware Tools, currently composed
of kernel modules for Linux and user-space programs for all VMware
supported Unix like guest operating systems.


%prep
%setup -q -n open-vm-tools-%{builddate}-%{buildver}


%build
%configure \
	--disable-static \
	--disable-dependency-tracking \
	--disable-unity \
	--without-kernel-modules \
	--without-root-privileges \
	--without-procps \
	--without-x \
        --host %{_arch}-unknown-linux-gnu 

make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name "*.la" -exec rm -f {} ';'

# Install vmware-guestd init script
mkdir -p $RPM_BUILD_ROOT/etc/init.d/
install -m 0755 %{SOURCE1} $RPM_BUILD_ROOT/etc/init.d/vmware-guest

# GPM vmmouse support
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig
cat <<EOF > $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/mouse
MOUSETYPE=imps2
XMOUSETYPE=IMPS/2
EOF

# Move mount.vmhgfs to correct location in /sbin
mkdir -p $RPM_BUILD_ROOT/sbin
mv $RPM_BUILD_ROOT%{_sbindir}/mount.* $RPM_BUILD_ROOT/sbin

# Install VMCI sockets header file
mkdir -p $RPM_BUILD_ROOT%{_includedir}/vmci
install -m 0644 modules/linux/vsock/linux/vmci_sockets.h $RPM_BUILD_ROOT%{_includedir}/vmci

# Move vmware-user desktop into autostart directory
#mkdir -p $RPM_BUILD_ROOT%{_datadir}/gnome/autostart
#mv $RPM_BUILD_ROOT%{_datadir}/applications/vmware-user.desktop $RPM_BUILD_ROOT%{_datadir}/gnome/autostart/
#cat <<EOF >>  $RPM_BUILD_ROOT%{_datadir}/gnome/autostart/vmware-user.desktop
#Type=Application
#EOF

# Install desktop file for toolbox
#mkdir -p $RPM_BUILD_ROOT%{_datadir}/applications
#cat <<EOF > $RPM_BUILD_ROOT%{_datadir}/applications/vmware-toolbox.desktop
#[Desktop Entry]
#Encoding=UTF-8
#Name=VMware Toolbox
#Comment=VMware Guest Toolbox
#Exec=vmware-toolbox
#Terminal=false
#Type=Application
#Categories=Gnome;Application;System
#StartupNotify=false
#EOF

# Install kernel modules sources for DKMS
mkdir -p $RPM_BUILD_ROOT%{_usrsrc}/%{tname}-%{builddate}
cp -r modules/linux/* $RPM_BUILD_ROOT%{_usrsrc}/%{tname}-%{builddate}/

# Install DKMS configuration file in src directory
cat <<EOF > $RPM_BUILD_ROOT%{_usrsrc}/%{tname}-%{builddate}/dkms.conf
PACKAGE_NAME=%{tname}
PACKAGE_VERSION=%{builddate}
MAKE[0]="make -C vmblock VM_UNAME=\$kernelver; make -C vmhgfs VM_UNAME=\$kernelver; make -C vmmemctl VM_UNAME=\$kernelver; make -C vmsync VM_UNAME=\$kernelver; make -C vmxnet VM_UNAME=\$kernelver; make -C vsock VM_UNAME=\$kernelver; make -C vmci VM_UNAME=\$kernelver"
CLEAN[0]="make -C vmblock clean; make -C vmhgfs clean; make -C vmmemctl clean; make -C vmsync clean; make -C vmxnet clean; make -C vsock clean; make -C vmci clean"
BUILT_MODULE_NAME[0]="vmblock"
BUILT_MODULE_NAME[1]="vmhgfs"
BUILT_MODULE_NAME[2]="vmmemctl"
BUILT_MODULE_NAME[3]="vmsync"
BUILT_MODULE_NAME[4]="vmxnet"
BUILT_MODULE_NAME[5]="vsock"
BUILT_MODULE_NAME[6]="vmci"
BUILT_MODULE_LOCATION[0]="vmblock/"
BUILT_MODULE_LOCATION[1]="vmhgfs/"
BUILT_MODULE_LOCATION[2]="vmmemctl/"
BUILT_MODULE_LOCATION[3]="vmsync/"
BUILT_MODULE_LOCATION[4]="vmxnet/"
BUILT_MODULE_LOCATION[5]="vsock/"
BUILT_MODULE_LOCATION[6]="vmci/"
DEST_MODULE_LOCATION[0]="/extra"
DEST_MODULE_LOCATION[1]="/extra"
DEST_MODULE_LOCATION[2]="/extra"
DEST_MODULE_LOCATION[3]="/extra"
DEST_MODULE_LOCATION[4]="/extra"
DEST_MODULE_LOCATION[5]="/extra"
DEST_MODULE_LOCATION[6]="/extra"
AUTOINSTALL="YES"
EOF

# Setup module-init-tools file for vmxnet
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/modprobe.d
cat <<EOF > $RPM_BUILD_ROOT%{_sysconfdir}/modprobe.d/vmnics
install pcnet32 /sbin/modprobe -q --ignore-install vmxnet; /sbin/modprobe -q --ignore-install pcnet32 $CMDLINE_OPTS; /bin/true;
EOF


%clean
rm -rf $RPM_BUILD_ROOT


%post
mkdir -p -m 1777 /tmp/VMwareDnD
# Register to DKMS
/usr/sbin/dkms add -m %{tname} -v %{builddate} -q || :
# Build for current kernel
/usr/sbin/dkms build -m %{tname} -v %{builddate} -q || :
/usr/sbin/dkms install -m %{tname} -v %{builddate} -q --force || :
# Setup guestd on initial install
[ $1 -lt 2 ] && /sbin/chkconfig vmware-guest on ||:
update-desktop-database %{_datadir}/applications > /dev/null 2>&1 || :


%postun
update-desktop-database %{_datadir}/applications > /dev/null 2>&1 || :


%preun
# Remove all versions from DKMS
/usr/sbin/dkms remove -m %{tname} -v %{builddate} -q --all || :
# Remove on uninstall
if [ "$1" = 0 ]
then
	/sbin/service vmware-guest stop || :
	/sbin/chkconfig vmware-guest off ||:
fi


%files
%defattr(-,root,root,-)
%doc AUTHORS COPYING ChangeLog NEWS README
%{_bindir}/vmware*
%{_sbindir}/vmware*
#%{_datadir}/applications/*.desktop
#%{_datadir}/gnome/autostart/*.desktop
/etc/init.d/*
%{_libdir}/*.so*
%{_includedir}/vmci
%{_sysconfdir}/pam.d/*
%config(noreplace) %{_sysconfdir}/vmware-tools
%{_sysconfdir}/sysconfig/mouse
%{_sysconfdir}/modprobe.d/*
%{_usrsrc}/%{tname}-%{builddate}
%attr(4755,root,root) /sbin/mount.vmhgfs
%attr(4755,root,root) %{_libdir}/%{tname}/plugins/vmsvc/*.so
%attr(4755,root,root) /usr/bin/vmtoolsd

#%attr(4755,root,root) %{_bindir}/vmware-user-suid-wrapper

%changelog
* Fri Feb 20 2009 Marek Goldmann <marek.goldmann@gmail.com> - 0.1.2009.02.18
- Update to upstream build 148847

* Mon Feb 2 2009 Marek Goldmann <marek.goldmann@gmail.com> - 0.1.2009.01.21
- Update to upstream build 142982

* Fri Jan 9 2009 Marek Goldmann <marek.goldmann@gmail.com> - 0.1.2008.12.23
- Update to upstream build 137496

* Mon Sep  8 2008 Denis Leroy <denis@poolshark.org> - 0-1.2008.09.03
- Update to 2008.09.03 upstream
- Added new kernel modules
- Marked configs as noreplace

* Sat May 17 2008 Denis Leroy <denis@poolshark.org> - 0-1.2008.05.15
- Update to upstream build 93241

* Wed Jan 30 2008 Denis Leroy <denis@poolshark.org> - 0-1.2008.01.23
- Update to 2008.01.23

* Fri Jan 25 2008 Denis Leroy <denis@poolshark.org> - 0-1.2007.11.21
- First draft

