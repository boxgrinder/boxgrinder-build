%global gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemname boxgrinder-build
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global rubyabi 1.8

Summary: A tool for creating appliances from simple plain text files
Name: rubygem-%{gemname}
Version: 0.6.1
Release: 1%{?dist}
Group: Development/Languages
License: LGPL
URL: http://www.jboss.org/boxgrinder
Source0: http://rubygems.org/gems/%{gemname}-%{version}.gem

Requires: ruby(abi) = %{rubyabi}
Requires: rubygems >= 1.2
Requires: ruby >= 0
Requires: rubygem(commander) => 4.0.3
Requires: rubygem(commander) < 4.1
Requires: rubygem(boxgrinder-core) => 0.1.0
Requires: rubygem(boxgrinder-core) < 0.2
BuildRequires: rubygems >= 1.2
BuildRequires: ruby >= 0

BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
A tool for creating appliances from simple plain text files for various
virtual environments

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
gem install --local --install-dir %{buildroot}%{gemdir} \
            --force --rdoc %{SOURCE0}
mkdir -p %{buildroot}/%{_bindir}
mv %{buildroot}%{gemdir}/bin/* %{buildroot}/%{_bindir}
rmdir %{buildroot}%{gemdir}/bin
find %{buildroot}%{geminstdir}/bin -type f | xargs chmod a+x

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%{_bindir}/boxgrinder-build
%dir %{geminstdir}
%{geminstdir}/bin
%{geminstdir}/lib
%doc %{gemdir}/doc/%{gemname}-%{version}
%doc %{geminstdir}/%{gemname}.gemspec
%doc %{geminstdir}/rubygem-%{gemname}.spec
%doc %{geminstdir}/CHANGELOG
%doc %{geminstdir}/LICENSE
%doc %{geminstdir}/README
%doc %{geminstdir}/Manifest
%doc %{geminstdir}/Rakefile
%doc %{geminstdir}/spec
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec

%changelog
* Mon Oct 18 2010  <mgoldman@redhat.com> - 0.6.1-1
- Initial package
