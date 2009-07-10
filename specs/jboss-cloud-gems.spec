Name:           jboss-cloud-gems
Version:        1.0.0.Beta6
Release:        1
Summary:        JBoss Cloud additional gems
Group:          System Environment/Base
License:        LGPL
URL:            http://oddthesis.org/
Source0:        http://rubyforge.org/frs/download.php/52464/xml-simple-1.0.12.gem
Source1:        http://rubyforge.org/frs/download.php/52548/mime-types-1.16.gem
Source2:        http://rubyforge.org/frs/download.php/21724/builder-2.1.2.gem
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:        ruby

%description
This package installs additional required gems.

%install
mkdir -p $RPM_BUILD_ROOT/usr/share/%{name}-gems
cp %{SOURCE0} $RPM_BUILD_ROOT/usr/share/%{name}-gems
cp %{SOURCE1} $RPM_BUILD_ROOT/usr/share/%{name}-gems
cp %{SOURCE2} $RPM_BUILD_ROOT/usr/share/%{name}-gems

%clean
rm -rf $RPM_BUILD_ROOT

%post
/usr/bin/gem install -q /usr/share/%{name}-gems/xml-simple-1.0.12.gem
/usr/bin/gem install -q /usr/share/%{name}-gems/builder-2.1.2.gem
/usr/bin/gem install -q /usr/share/%{name}-gems/mime-types-1.16.gem

%files
%defattr(-,root,root,-)
/

%changelog
* Fri Jul 10 2009 Marek Goldmann 1.0.0.Beta6
- Initial packaging
