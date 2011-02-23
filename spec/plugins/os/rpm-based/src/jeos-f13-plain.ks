lang en_US.UTF-8
keyboard us
timezone US/Eastern
auth --useshadow --enablemd5
selinux --permissive
firewall --disabled
bootloader --timeout=1 --append="acpi=force scsi_mod.scan=sync"
firstboot --disabled
network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network
rootpw boxgrinder

part / --size 2048 --fstype ext4  --ondisk sda

repo --name=fedora-14-base --cost=40 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-13&arch=x86_64
repo --name=fedora-14-updates --cost=41 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f13&arch=x86_64

%packages --excludedocs --nobase
  @core
%end
