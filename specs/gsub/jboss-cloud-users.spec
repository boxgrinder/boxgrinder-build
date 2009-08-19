Name:           jboss-cloud-#APPLIANCE_NAME#-users
Version:        1.0.0.Beta7
Release:        1
Summary:        Required user accounts for JBoss Cloud
License:        LGPL
URL:            http://oddthesis.org/
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:       shadow-utils

%description
Required user accounts for JBoss Cloud.

%clean
rm -rf $RPM_BUILD_ROOT

%pre
#USERS#

%changelog
* Tue Aug 18 2009 Marek Goldmann 1.0.0.Beta7
- Initial packaging
