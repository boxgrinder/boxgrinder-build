%global gem_name boxgrinder-build

%{!?gem_dir: %global gem_dir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)}
%{!?gem_instdir: %global gem_instdir %{gem_dir}/gems/%{gem_name}-%{version}}

%if 0%{?fedora} >= 17
%global rubyabi 1.9.1
%else
%global rubyabi 1.8
%endif

Summary:     A tool for creating appliances from simple plain text files
Name:        rubygem-%{gem_name}
Version:     0.10.3
Release:     1%{?dist}
Group:       Development/Languages
License:     LGPLv3+
URL:         http://boxgrinder.org/
Source0:     http://rubygems.org/gems/%{gem_name}-%{version}.gem

Requires: ruby(abi) = %{rubyabi}
Requires: rubygem(boxgrinder-core) >= 0.3.12
Requires: rubygem(boxgrinder-core) < 0.4.0
Requires: ruby-libguestfs

BuildArch: noarch

BuildRequires: rubygems-devel
BuildRequires: rubygem(rake)
BuildRequires: rubygem(boxgrinder-core) >= 0.3.12
BuildRequires: rubygem(boxgrinder-core) < 0.4.0
BuildRequires: rubygem(echoe)
BuildRequires: ruby-libguestfs

%if 0%{?fedora} >= 17
BuildRequires: rubygem(rspec)
%else
BuildRequires: rubygem(rspec-core)
%endif

# AWS
Requires: euca2ools >= 1.3.1-4
Requires: rubygem(aws-sdk) >= 1.1.1

BuildRequires: rubygem(aws-sdk) >= 1.1.1

# SFTP
Requires: rubygem(net-sftp)
Requires: rubygem(net-ssh)
Requires: rubygem(progressbar)

BuildRequires: rubygem(net-sftp)
BuildRequires: rubygem(net-ssh)
BuildRequires: rubygem(progressbar)

# libvirt
Requires: ruby-libvirt
Requires: rubygem(nokogiri)
Requires: rubygem(builder)

BuildRequires: ruby-libvirt
BuildRequires: rubygem(nokogiri)
BuildRequires: rubygem(builder)

# RPM-BASED
Requires: appliance-tools >= 006.1-1
Requires: yum-utils

# ElasticHosts
Requires: rubygem(rest-client)

BuildRequires: rubygem(rest-client)

Provides: rubygem(%{gem_name}) = %{version}

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
rm -rf %{_builddir}%{gem_dir}

mkdir -p %{_builddir}%{gem_dir}
mkdir -p %{buildroot}/%{_bindir}
mkdir -p %{buildroot}/%{gem_dir}

/usr/bin/gem install --local --install-dir %{_builddir}%{gem_dir} \
            --force --rdoc %{SOURCE0}
mv %{_builddir}%{gem_dir}/bin/* %{buildroot}/%{_bindir}
find %{_builddir}%{gem_instdir}/bin -type f | xargs chmod a+x
rm -rf %{_builddir}/%{gem_instdir}/integ/packages/*.rpm
cp -r %{_builddir}%{gem_dir}/* %{buildroot}/%{gem_dir}

install -d -m 755 %{buildroot}/%{_sysconfdir}/bash_completion.d
mv %{buildroot}/%{gem_instdir}/bash_completion %{buildroot}/%{_sysconfdir}/bash_completion.d/%{name}

chmod +x %{buildroot}/%{gem_instdir}/lib/boxgrinder-build/helpers/qemu.wrapper

%check
pushd %{_builddir}/%{gem_instdir}
rspec -r spec_helper -r boxgrinder-core -I. -P 'spec/**/*-spec.rb'
popd

%files
%{_bindir}/boxgrinder-build
%{_sysconfdir}/bash_completion.d/%{name}
%dir %{gem_instdir}
%{gem_instdir}/bin
%{gem_libdir}
%doc %{gem_instdir}/CHANGELOG
%doc %{gem_instdir}/LICENSE
%doc %{gem_instdir}/README.md
%doc %{gem_instdir}/Manifest
%{gem_cache}
%{gem_spec}

%files doc
%{gem_instdir}/spec
%{gem_instdir}/integ
%{gem_instdir}/Rakefile
%{gem_instdir}/rubygem-%{gem_name}.spec
%{gem_instdir}/%{gem_name}.gemspec
%{gem_docdir}

%changelog
* Mon Jun 18 2012 Marc Savy <msavy@redhat.com> - 0.10.3
- Upstream release: 0.10.3
- [BGBUILD-339] Existing rpm package with the name containing '+' considered as an invalid name
- [BGBUILD-359] Enable more than 4 partitions in msdos partition layout

* Thu May 24 2012 Marc Savy <msavy@redhat.com> - 0.10.2
- Upstream release: 0.10.2
- [BGBUILD-347] Add support for Fedora 17. Remove unnecessary OS restrictions
- [BGBUILD-353] Remove all default attaching (EBS) and mounting (EBS, S3)
- [BGBUILD-361] Yum runs before having a proper /etc/resolv.conf (EC2 & CentOS 5)

* Wed Feb 29 2012 Marc Savy <msavy@redhat.com> - 0.10.1-1
- Upstream release: 0.10.1
- [BGBUILD-332] Add support for bash completion
- [BGBUILD-338] Weed out non-deterministic tests
- [BGBUILD-337] In SL if default repos are disabled, /etc/yum.repos.d folder is not created
- [BGBUILD-344] New filesystem monitoring improvements (Fixes: Shifting failed. Permission denied issues)
- [BGBUILD-345] Change sudo/chown magic so it only occurs when running without explicit sudo/su (or --change-to-user)
- [BGBUILD-346] Confirm Ruby 1.9.3 support
- [BGBUILD-348] Simplecov coverage testing for Ruby >=1.9
- [BGBUILD-349] Use RbConfig instead of obsolete and deprecated Config deprecation warning with Ruby 1.9.3


* Tue Dec 27 2011 Marek Goldmann <mgoldman@redhat.com> - 0.11.0-1
- Upstream release: 0.11.0
- [BGBUILD-332] Add support for bash completion
- [BGBUILD-338] Weed out non-deterministic tests
- [BGBUILD-337] In SL if default repos are disabled, /etc/yum.repos.d folder is not created.

* Tue Nov 29 2011 Marek Goldmann <mgoldman@redhat.com> - 0.10.0-1
- Upstream release: 0.10.0
- [BGBUILD-313] boxgrinder build fails to build ec2 image if ec2-user already exists
- [BGBUILD-318] Add support for us-west-2 region
- [BGBUILD-308] Clearer error message when unrecognised file extension is used
- [BGBUILD-322] Allow selection of kernel and ramdisk for ec2 and ebs plugins
- [BGBUILD-302] Add support for VirtualPC platform
- [BGBUILD-195] Add support for OpenStack
- [BGBUILD-304] Standarize plugin callbacks
- [BGBUILD-325] Remove kickstart support
- [BGBUILD-323] Invalid kernel version recognition makes recreating initrd impossible
- [BGBUILD-326] Ensure building from root directory is successful
- [BGBUILD-211] Support for registering appliances with libvirt
- [BGBUILD-331] Add support for sa-east-1 EC2 region

* Fri Oct 14 2011 Marc Savy <msavy@redhat.com> - 0.9.8-1
- Upstream release: 0.9.8
- [BGBUILD-312] Only use root privileges when necessary
- [BGBUILD-267] Add CentOS 6 support
- [BGBUILD-310] BoxGrinder doesn't build appliances when Fedora 16 is the host
- [BGBUILD-157] Add Alignment options for virtual appliances
- [BGBUILD-321] For EBS AMIs use the filesystem type specified for root partition

* Tue Sep 06 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.7-1
- Upstream release: 0.9.7
- [BGBUILD-307] Appliance with swap file fails to build if selected OS is centos
- [BGBUILD-306] Switch for updates-testing repository for integration tests

* Sat Aug 27 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.6-1
- Upstream release: 0.9.6
- [BGBUILD-298] Fedora 16 or newer has networking issue on platforms different than EC2 because of biosdevname not disabled
- [BGBUILD-299] Wrong filenames in GRUB discovery
- [BGBUILD-276] Import files into appliance via appliance definition file (Files section)
- [BGBUILD-300] Add support for swap partitions
- [BGBUILD-301] Swap feature not working properly

* Sat Aug 27 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.5.3-1
- Upstream release: 0.9.5.3

* Sat Aug 27 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.5.2-1
- Upstream release: 0.9.5.2
- More mocking in specs preventing remote calls - now for real

* Sat Aug 27 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.5.1-1
- Upstream release: 0.9.5.1
- More mocking in specs preventing remote calls

* Thu Aug 23 2011 Marek Goldmann <mgoldman@redhat.com> - 0.9.5-1
- Upstream release: 0.9.5
- [BGBUILD-294] Package aws-sdk 1.1.1 and update dependency
- [BGBUILD-277] When delivering as AMI, the EC2 region should match S3 bucket's region (location constraint)
- [BGBUILD-297] Cannot create EBS appliances when using overwrite parameter
- [BGBUILD-280] Add support for GRUB2
- [BGBUILD-279] Add support for Fedora 16
- [BGBUILD-293] Check certificate and key paths are valid before building AMIs

* Fri Aug 12 2011 Marc Savy <msavy@redhat.com> - 0.9.4-1
- Upstream release: 0.9.4
- [BGBUILD-263] NoMethodError: undefined method `item' for nil:NilClass while creating EBS appliance
- [BGBUILD-246] Detect when insufficient system memory is available for standard libguestfs, and reduce allocation.
- [BGBUILD-269] RPM database is recreated after post section execution preventing installing RPM in post section
- [BGBUILD-273] Move to RSpec2
- [BGBUILD-272] Move from aws and amazon-ec2 to official aws-sdk gem
- [BGBUILD-238] Stop AWS gem warnings
- [BGBUILD-265] Resolve concurrency issues in S3 plugin for overwriting
- [BGBUILD-249] Warning from S3 AMI plugin that BG is attempting to create a bucket that already exists
- [BGBUILD-242]	Additional EBS overwrite edge cases

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
