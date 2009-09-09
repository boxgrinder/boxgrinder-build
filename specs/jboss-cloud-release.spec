Name:           jboss-cloud-release
Version:        1.0.0.Beta8
Release:        1
Summary:        JBoss Cloud release files
Group:          System Environment/Base
License:        LGPL
URL:            http://oddthesis.org/
Source:         %{name}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

%description
This package installs base GPG keys and repositories.

%prep
%setup -n %{name}

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT/etc/sysconfig
echo "JBoss Cloud release %{version}" > $RPM_BUILD_ROOT/etc/jboss-cloud-release
echo "JBOSS_CLOUD_VERSION=%{version}" > $RPM_BUILD_ROOT/etc/sysconfig/jboss-cloud

# gpg
install -d -m 755 $RPM_BUILD_ROOT/etc/pki/rpm-gpg
install -m 644 RPM-GPG-KEY* $RPM_BUILD_ROOT/etc/pki/rpm-gpg/

# yum
install -d -m 755 $RPM_BUILD_ROOT/etc/yum.repos.d
cat oddthesis.repo > $RPM_BUILD_ROOT/etc/yum.repos.d/oddthesis.repo

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%config %attr(0644,root,root) /etc/jboss-cloud-release
%dir /etc/yum.repos.d
%config(noreplace) /etc/yum.repos.d/*
%dir /etc/pki/rpm-gpg
/etc/pki/rpm-gpg/*
/etc/sysconfig/jboss-cloud

%changelog
* Tue Mar 10 2009 Marek Goldmann <marek.goldmann@gmail.com> jboss-cloud-release-1.0.0.Beta3
- Renaming, added Provides, repos and keys from fedora 

* Thu Jan 15 2009 Marek Goldmann <marek.goldmann@gmail.com> oddthesis-repo-1.0
- First spec file based upon Gregory R. Kriehn HOWTO
  (http://optics.csufresno.edu/~kriehn/fedora/fedora_files/f8/howto/yum-repository.html).
