%global gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemname boxgrinder-build
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global rubyabi 1.8

Summary: A tool for creating appliances from simple plain text files
Name: rubygem-%{gemname}
Version: 0.6.4
Release: 2%{?dist}
Group: Development/Languages
License: LGPLv3+
URL: http://www.jboss.org/boxgrinder
Source0: http://rubygems.org/gems/%{gemname}-%{version}.gem

Requires: ruby(abi) = %{rubyabi}
Requires: rubygem(commander)
Requires: rubygem(boxgrinder-core)

BuildRequires: rubygem(rake)
BuildRequires: rubygem(rspec)
BuildRequires: rubygem(boxgrinder-core)
BuildRequires: rubygem(echoe)

BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
A tool for creating appliances from simple plain text files for various
virtual environments

%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires:%{name} = %{version}-%{release}

%description doc
Documentation for %{name}

%prep

%build

%install
rm -rf %{buildroot}
rm -rf %{_builddir}%{gemdir}

mkdir -p %{_builddir}%{gemdir}
mkdir -p %{buildroot}/%{_bindir}
mkdir -p %{buildroot}/%{gemdir}

gem install --local --install-dir %{_builddir}%{gemdir} \
            --force --rdoc %{SOURCE0}
mv %{_builddir}%{gemdir}/bin/* %{buildroot}/%{_bindir}
find %{_builddir}%{geminstdir}/bin -type f | xargs chmod a+x
cp -r %{_builddir}%{gemdir}/* %{buildroot}/%{gemdir}

%check
pushd %{_builddir}/%{geminstdir}
rake spec
popd

%files
%defattr(-, root, root, -)
%{_bindir}/boxgrinder-build
%dir %{geminstdir}
%{geminstdir}/bin
%{geminstdir}/lib
%doc %{geminstdir}/CHANGELOG
%doc %{geminstdir}/LICENSE
%doc %{geminstdir}/README
%doc %{geminstdir}/Manifest
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec

%files doc
%defattr(-, root, root, -)
%{geminstdir}/spec
%{geminstdir}/Rakefile
%{geminstdir}/rubygem-%{gemname}.spec
%{geminstdir}/%{gemname}.gemspec
%{gemdir}/doc/%{gemname}-%{version}

%changelog
* Sat Nov 20 2010  <mgoldman@redhat.com> - 0.6.4-2
- [BGBUILD-99] Timeout exception is not catched on non-EC2 platfrom in GuestFSHelper

* Mon Nov 15 2010  <mgoldman@redhat.com> - 0.6.4-1
- Removed BuildRoot tag
- Adjusted Requires and BuildRequires
- Different approach for testing
- [BGBUILD-98] Use hashery gem

* Tue Nov 09 2010  <mgoldman@redhat.com> - 0.6.3-1
- [BGBUILD-94] Check if set_network call is avaialbe in libguestfs
- Added 'check' section that executes tests

* Wed Nov 03 2010  <mgoldman@redhat.com> - 0.6.2-1
- [BGBUILD-84] Don't use in libguestfs qemu-kvm where hardware accleration isn't available

* Mon Oct 18 2010  <mgoldman@redhat.com> - 0.6.1-1
- Initial package
