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

%install
install -d -m 755 $RPM_BUILD_ROOT/etc/sysconfig/ 
touch $RPM_BUILD_ROOT/etc/sysconfig/jboss-cloud-users 

%clean
rm -rf $RPM_BUILD_ROOT

%pre
#USERS#

%files
%defattr(-,root,root,-)
%config %attr(0644,root,root) /etc/sysconfig/jboss-cloud-users
/

%changelog
* Tue Aug 18 2009 Marek Goldmann 1.0.0.Beta7
- Initial packaging
