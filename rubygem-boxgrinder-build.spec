%global gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemname boxgrinder-build
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global rubyabi 1.8

Summary: A tool for creating appliances from simple plain text files
Name: rubygem-%{gemname}
Version: 0.8.0
Release: 1%{?dist}
Group: Development/Languages
License: LGPLv3+
URL: http://www.jboss.org/boxgrinder
Source0: http://rubygems.org/gems/%{gemname}-%{version}.gem
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires: ruby(abi) = %{rubyabi}
Requires: rubygem(thor)
Requires: rubygem(boxgrinder-core) >= 0.2.0
Requires: ruby-libguestfs
Requires: parted
Requires: e2fsprogs

BuildRequires: rubygem(rake)
BuildRequires: rubygem(rspec)
BuildRequires: rubygem(boxgrinder-core) >= 0.2.0
BuildRequires: rubygem(echoe)
BuildRequires: ruby-libguestfs

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
%{_bindir}/boxgrinder
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
* Tue Jan 04 2011  <mgoldman@redhat.com> - 0.8.0-1
- Upstream release: 0.8.0
- Added BuildRoot tag to build for EPEL 5
- [BGBUILD-128] Allow to specify plugin configuration using CLI
- [BGBUILD-134] Replace rubygem-commander with rubygem-thor
- [BGBUILD-79] Allow to use BoxGrinder Build as a library
- [BGBUILD-127] Use appliance definition object instead of a file when using BG as a library
- [BGBUILD-68] Global .boxgrinder/config or rc style file for config
- [BGBUILD-131] Check if OS is supported before executing the plugin
- [BGBUILD-72] Add support for growing (not pre-allocated) disks for KVM/Xen
- [BGBUILD-133] Support a consolidated configuration file
- [BGBUILD-138] enablerepo path is not escaped when calling repoquery

* Mon Dec 20 2010  <mgoldman@redhat.com> - 0.7.1-1
- Upstream release: 0.7.1
- [BGBUILD-123] Remove RPM database recreation code
- [BGBUILD-124] Guestfs fails while mounting multiple partitions with '_' prefix

* Fri Dec 17 2010  <mgoldman@redhat.com> - 0.7.0-1
- Updated to upstream version: 0.7.0
- [BGBUILD-113] Allow to specify supported file formats for operating system plugin
- [BGBUILD-73] Add support for kickstart files
- [BGBUILD-80] VMware .tgz Bundle Should Expand Into Subdirectory, Not Current Directory
- [BGBUILD-118] Enable SElinux in guestfs
- [BGBUILD-119] Fix SElinux issues on EC2 appliances

* Thu Dec 02 2010  <mgoldman@redhat.com> - 0.6.5-1
- Updated to new upstream release: 0.6.5

* Mon Nov 22 2010  <mgoldman@redhat.com> - 0.6.4-3
- Changelog rewritten
- Added Require: parted and e2fsprogs

* Sat Nov 20 2010  <mgoldman@redhat.com> - 0.6.4-2
- Small set of spec file adjustments

* Mon Nov 15 2010  <mgoldman@redhat.com> - 0.6.4-1
- Updated to new upstream release: 0.6.4
- Removed BuildRoot tag
- Adjusted Requires and BuildRequires
- Different approach for testing
- [BGBUILD-98] Use hashery gem
- [BGBUILD-99] Timeout exception is not catched on non-EC2 platfrom in GuestFSHelper
- [BGBUILD-92] Enable --trace switch by default
- [BGBUILD-91] Log exceptions to log file

* Tue Nov 09 2010  <mgoldman@redhat.com> - 0.6.3-1
- [BGBUILD-94] Check if set_network call is avaialbe in libguestfs
- Added 'check' section that executes tests

* Wed Nov 03 2010  <mgoldman@redhat.com> - 0.6.2-1
- [BGBUILD-84] Don't use in libguestfs qemu-kvm where hardware accleration isn't available

* Mon Oct 18 2010  <mgoldman@redhat.com> - 0.6.1-1
- Initial package
