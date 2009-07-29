%define builddate 2009.07.22
%define buildver 179896

Name:      open-vm-tools
Version:   0.0.0.%{buildver}
Release:   1%{?dist}
Summary:   VMware Guest OS Tools
Group:     Applications/System
License:   LGPLv2
URL:       http://open-vm-tools.sourceforge.net/
Source0:   http://downloads.sourceforge.net/%{name}/%{name}-%{builddate}-%{buildver}.tar.gz
Source1:   %{name}-vmtoolsd.init
Source2:   %{name}-sysconfig.mouse
Source3:   vmware-toolbox.desktop
Source4:   %{name}-modprobe.vmnics
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
