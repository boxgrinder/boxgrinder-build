Summary: A test spec for use in verifying ephemeral repo functionality of BoxGrinder
Name: ephemeral-repo-test
Version: 0.1
Release: 1
License: GPLv3
Packager: Marc Savy 
BuildArch: noarch

%description
A test spec for use in verifying ephemeral repo functionality in BoxGrinder

%install
touch $RPM_BUILD_ROOT/repos-boxgrinder-noarch-ephemeral-boxgrinder-test

%files
%defattr(-,root,root)
/
