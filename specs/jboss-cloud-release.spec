%define dist_version 1

Name:           jboss-cloud-release
Version:        1.0.0.Beta3
Release:        2
Summary:        JBoss-Cloud release files
Group:          System Environment/Base
License:        LGPL
URL:            http://oddthesis.org/
Source:         %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

Obsoletes:      redhat-release
Provides:       redhat-release
Provides:       system-release = %{version}-%{release}

%description
This package installs base GPG keys and repositories.

%prep
%setup -n %{name}-%{version}

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT/etc
echo "JBoss-Cloud release %{version}" > $RPM_BUILD_ROOT/etc/jboss-cloud-release
echo "cpe://o:jboss:jboss-cloud:%{version}" > $RPM_BUILD_ROOT/etc/system-release-cpe
cp -p $RPM_BUILD_ROOT/etc/jboss-cloud-release $RPM_BUILD_ROOT/etc/issue
echo "Kernel \r on an \m (\l)" >> $RPM_BUILD_ROOT/etc/issue
cp -p $RPM_BUILD_ROOT/etc/issue $RPM_BUILD_ROOT/etc/issue.net
echo >> $RPM_BUILD_ROOT/etc/issue
ln -s jboss-cloud-release $RPM_BUILD_ROOT/etc/redhat-release
ln -s jboss-cloud-release $RPM_BUILD_ROOT/etc/system-release

# gpg
install -d -m 755 $RPM_BUILD_ROOT/etc/pki/rpm-gpg
install -m 644 RPM-GPG-KEY* $RPM_BUILD_ROOT/etc/pki/rpm-gpg/

# yum
install -d -m 755 $RPM_BUILD_ROOT/etc/yum.repos.d
cat oddthesis.repo | sed "s/#distro#/%{distro}/g" > $RPM_BUILD_ROOT/etc/yum.repos.d/oddthesis.repo

for file in *.repo ; do
  install -m 644 $file $RPM_BUILD_ROOT/etc/yum.repos.d
done

# Set up the dist tag macros
install -d -m 755 $RPM_BUILD_ROOT/etc/rpm
cat >> $RPM_BUILD_ROOT/etc/rpm/macros.dist << EOF
# dist macros.

%%jboss-cloud     %{dist_version}
%%dist            .cloud%{dist_version}
%%cloud%{dist_version}   1
EOF

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%config %attr(0644,root,root) /etc/jboss-cloud-release
/etc/redhat-release
/etc/system-release
%config %attr(0644,root,root) /etc/system-release-cpe
%dir /etc/yum.repos.d
%config(noreplace) /etc/yum.repos.d/*
%config(noreplace) %attr(0644,root,root) /etc/issue
%config(noreplace) %attr(0644,root,root) /etc/issue.net
%config %attr(0644,root,root) /etc/rpm/macros.dist
%dir /etc/pki/rpm-gpg
/etc/pki/rpm-gpg/*



%changelog
* Tue Mar 10 2009 Marek Goldmann <marek.goldmann@gmail.com> jboss-cloud-release-1.0.0.Beta3
- Renaming, added Provides, repos and keys from fedora 

* Thu Jan 15 2009 Marek Goldmann <marek.goldmann@gmail.com> oddthesis-repo-1.0
- First spec file based upon Gregory R. Kriehn HOWTO
  (http://optics.csufresno.edu/~kriehn/fedora/fedora_files/f8/howto/yum-repository.html).
