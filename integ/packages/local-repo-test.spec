%define post_name repos-boxgrinder-noarch-ephemeral-boxgrinder-test
Summary: A test spec for use in verifying ephemeral repo functionality of BoxGrinder
Name: ephemeral-repo-test
Version: 0.1
Release: 1
License: GPLv3
Packager: Marc Savy 
Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
BuildArch: noarch
Group: other

%description
A test spec for use in verifying ephemeral repo functionality in BoxGrinder

%prep
%setup

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir $RPM_BUILD_ROOT
install -m664 %{name} $RPM_BUILD_ROOT/%{post_name}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/%{post_name}
