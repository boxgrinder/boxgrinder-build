%global gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemname boxgrinder-build
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global rubyabi 1.8

Summary: A tool for creating appliances from simple plain text files
Name: rubygem-%{gemname}
Version: 0.9.4
Release: 1%{?dist}
Group: Development/Languages
License: LGPLv3+
URL: http://boxgrinder.org/
Source0: http://rubygems.org/gems/%{gemname}-%{version}.gem

Requires: ruby(abi) = %{rubyabi}
Requires: rubygem(boxgrinder-core) >= 0.3.0
Requires: rubygem(boxgrinder-core) < 0.4.0
Requires: ruby-libguestfs

# Fix for rubygem-aws package
Requires: rubygem(activesupport)

BuildArch: noarch

BuildRequires: rubygem(rake)
BuildRequires: rubygem(boxgrinder-core) >= 0.3.0
BuildRequires: rubygem(boxgrinder-core) < 0.4.0
BuildRequires: rubygem(echoe)
BuildRequires: ruby-libguestfs
# Use rspec-core until rspec are migrated to RSpec 2.x
BuildRequires: rubygem(rspec-core)

# Fix for rubygem-aws package
BuildRequires: rubygem(activesupport)

# Fixes blankslate error
Requires: rubygem(builder)
Requires: rubygem(aws-sdk)
Requires: euca2ools >= 1.3.1-4

BuildRequires: rubygem(amazon-ec2)
BuildRequires: rubygem(aws)
# Fixes blankslate error
BuildRequires: rubygem(builder)

# SFTP
Requires: rubygem(net-sftp)
Requires: rubygem(net-ssh)
Requires: rubygem(progressbar)

BuildRequires: rubygem(net-sftp)
BuildRequires: rubygem(net-ssh)
BuildRequires: rubygem(progressbar)

# RPM-BASED
Requires: appliance-tools
Requires: yum-utils

# ElasticHosts
Requires: rubygem(rest-client)

BuildRequires: rubygem(rest-client)

Provides: rubygem(%{gemname}) = %{version}

Obsoletes: rubygem(boxgrinder-build-ebs-delivery-plugin) < 0.0.4-2
Obsoletes: rubygem(boxgrinder-build-s3-delivery-plugin) < 0.0.6-1
Obsoletes: rubygem(boxgrinder-build-local-delivery-plugin) < 0.0.6-2
Obsoletes: rubygem(boxgrinder-build-sftp-delivery-plugin) < 0.0.5-2
Obsoletes: rubygem(boxgrinder-build-fedora-os-plugin) < 0.0.6-2
Obsoletes: rubygem(boxgrinder-build-rpm-based-os-plugin) < 0.0.11-1
Obsoletes: rubygem(boxgrinder-build-ec2-platform-plugin) < 0.0.10-2
Obsoletes: rubygem(boxgrinder-build-vmware-platform-plugin) < 0.0.10-2

Provides: rubygem(boxgrinder-build-ebs-delivery-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-s3-delivery-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-local-delivery-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-sftp-delivery-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-fedora-os-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-rpm-based-os-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-ec2-platform-plugin) = %{version}-%{release}
Provides: rubygem(boxgrinder-build-vmware-platform-plugin) = %{version}-%{release}

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

/usr/bin/gem install --local --install-dir %{_builddir}%{gemdir} \
            --force --rdoc %{SOURCE0}
mv %{_builddir}%{gemdir}/bin/* %{buildroot}/%{_bindir}
find %{_builddir}%{geminstdir}/bin -type f | xargs chmod a+x
rm -rf %{_builddir}/%{geminstdir}/integ/packages/*.rpm
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
%doc %{geminstdir}/README.md
%doc %{geminstdir}/Manifest
%attr(755, root, root) %{geminstdir}/lib/boxgrinder-build/helpers/qemu.wrapper
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec

%files doc
%defattr(-, root, root, -)
%{geminstdir}/spec
%{geminstdir}/integ
%{geminstdir}/Rakefile
%{geminstdir}/rubygem-%{gemname}.spec
%{geminstdir}/%{gemname}.gemspec
%{gemdir}/doc/%{gemname}-%{version}

%changelog

* Wed Jun 29 2011 Marc Savy <msavy@redhat.com> - 0.9.4-1
- Upstream release: 0.9.4
- [BGBUILD-263] NoMethodError: undefined method `item' for nil:NilClass while creating EBS appliance
- [BGBUILD-246] Detect when insufficient system memory is available for standard libguestfs, and reduce allocation.
- [BGBUILD-269] RPM database is recreated after post section execution preventing installing RPM in post section
- [BGBUILD-273] Move to RSpec2

* Fri Jun 17 2011 Marc Savy <msavy@redhat.com> - 0.9.3-1
- Upstream release: 0.9.3
- [BGBUILD-232] boxgrinder doesn't validate config early enough
- [BGBUILD-237] Tilde characters break creation of yum.conf
- [BGBUILD-223] BoxGrinder hangs because qemu.wrapper does not detect x86_64 properly on CentOS 5.6
- [BGBUILD-241] Add Scientific Linux support
- [BGBUILD-220] Group names have spaces (to the user), this breaks schema rules for packages
- [BGBUILD-222] Allow overwrite of uploaded ec2 image
- [BGBUILD-225] Move PAE configuration parameter to operating system configuration
- [BGBUILD-224] EBS Plugin Support for CentOS v5.5 and fix for non-integer EBS disk sizes
- [BGBUILD-231] Cannot register Fedora 15 EC2 AMI with S3 delivery plugin in eu-west-1 availability zone
- [BGBUILD-193] EBS delivery plugin timing/concurrency issues
- [BGBUILD-247] ap-northeast-1 end-point is missing in S3 plugin (added Tokyo region)
- [BGBUILD-251] Add ap-northeast-1 (tokyo) region for EBS plugin
- [BGBUILD-248] Throw error in S3 plugin if invalid region is specified
- [BGBUILD-252] rc.local script fills ~/.ssh/authorized_keys with a duplicate key every boot
- [BGBUILD-250] EBS plugin incorrectly determines that non-US regions are not EC2 instances
- [BGBUILD-254] Not able to deliver EBS AMIs to regions other than us-east-1
- [BGBUILD-260] Wrong EC2 discovery causing libguestfs errors on non US regions
- [BGBUILD-261] Decrease amount of debug log when downloading or uploading file using guestfs

* Thu May 05 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.2-1
- Upstream release: 0.9.2
- [BGBUILD-148] Add support for building CentOS/RHEL images on Fedora
- [BGBUILD-204] Fedora 15 appliance networking start on boot failed
- [BGBUILD-208] Kickstart files not working with 0.9.1
- [BGBUILD-205] Error while converting to EC2 when guest OS is CentOS/RHEL 5
- [BGBUILD-213] CloudSigma support
- [BGBUILD-209] Wrong /etc/mtab on Fedora 15 appliances causes errors
- [BGBUILD-203] Vmware vmdk disk size is wrong when installing via kickstart files
- [BGBUILD-207] Guestfs dies on Fedora 15 with 'KVM not supported for this target' message
- [BGBUILD-83] Enable libguestfs log callback to redirect guestfs output to logger

* Thu Mar 17 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.1-1
- Upstream release: 0.9.1
- [BGBUILD-188] Use libuestfs instead mounting partitions manually for EC2 appliances
- [BGBUILD-97] some filesystems dont get unmounted on BG interruption
- [BGBUILD-155] Images built on Centos5.x (el5) for VirtualBox kernel panic (/dev/root missing)
- [BGBUILD-190] Allow to specify kernel variant (PAE or not) for Fedora OS
- [BGBUILD-196] GuestFS fails mounting partitions where more then 3 partitions are present
- [BGBUILD-200] /sbin/e2label: Filesystem has unsupported feature(s) while trying to open /dev/sda1
- [BGBUILD-194] Add support for ElasticHosts cloud
- [BGBUILD-202] Unable to get valid context for ec2-user after login on AMI

* Tue Mar 01 2011 Marc Savy <msavy@redhat.com> - 0.9.0-1
- Upstream release: 0.9.0
- [BGBUILD-103] README to indicate supported operating systems / requirements
- [BGBUILD-169] S3 plugin temporary work-around for EL5
- [BGBUILD-174] Move plugins to boxgrinder-build gem
- [BGBUILD-175] Rewrite boxgrinder CLI to remove thor dependency
- [BGBUILD-81] post command execution w/ setarch breaks commands which are scripts
- [BGBUILD-173] Include setarch package in default package list for RPM-based OSes
- [BGBUILD-177] Fedora 13 builds have enabled firewall although they shouldn't have it
- [BGBUILD-178] Remove sensitive data from logs
- [BGBUILD-179] Boolean and numeric parameters in hash-like values are not recognized
- [BGBUILD-176] Fail the build with appropriate message if any of post section commands fails to execute
- [BGBUILD-183] Add support for Fedora 15

* Tue Feb 16 2011 Marek Goldmann <mgoldman@redhat.com> - 0.8.1-1
- Upstream release: 0.8.1
- [BGBUILD-141] Long delay after "Preparing guestfs" message when creating new image
- [BGBUILD-150] Cyclical inclusion dependencies in appliance definition files are not detected/handled
- [BGBUILD-165] Use version in dependencies in gem and in RPM only where necessary

* Tue Jan 04 2011 Marek Goldmann <mgoldman@redhat.com> - 0.8.0-1
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
- [BGBUILD-147] Allow to list installed plugins and version information

* Mon Dec 20 2010 Marek Goldmann <mgoldman@redhat.com> - 0.7.1-1
- Upstream release: 0.7.1
- [BGBUILD-123] Remove RPM database recreation code
- [BGBUILD-124] Guestfs fails while mounting multiple partitions with '_' prefix

* Fri Dec 17 2010 Marek Goldmann <mgoldman@redhat.com> - 0.7.0-1
- Updated to upstream version: 0.7.0
- [BGBUILD-113] Allow to specify supported file formats for operating system plugin
- [BGBUILD-73] Add support for kickstart files
- [BGBUILD-80] VMware .tgz Bundle Should Expand Into Subdirectory, Not Current Directory
- [BGBUILD-118] Enable SElinux in guestfs
- [BGBUILD-119] Fix SElinux issues on EC2 appliances

* Thu Dec 02 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.5-1
- Updated to new upstream release: 0.6.5

* Mon Nov 22 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.4-3
- Changelog rewritten
- Added Require: parted and e2fsprogs

* Sat Nov 20 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.4-2
- Small set of spec file adjustments

* Mon Nov 15 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.4-1
- Updated to new upstream release: 0.6.4
- Removed BuildRoot tag
- Adjusted Requires and BuildRequires
- Different approach for testing
- [BGBUILD-98] Use hashery gem
- [BGBUILD-99] Timeout exception is not catched on non-EC2 platfrom in GuestFSHelper
- [BGBUILD-92] Enable --trace switch by default
- [BGBUILD-91] Log exceptions to log file

* Tue Nov 09 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.3-1
- [BGBUILD-94] Check if set_network call is avaialbe in libguestfs
- Added 'check' section that executes tests

* Wed Nov 03 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.2-1
- [BGBUILD-84] Don't use in libguestfs qemu-kvm where hardware accleration isn't available

* Mon Oct 18 2010 Marek Goldmann <mgoldman@redhat.com> - 0.6.1-1
- Initial package
