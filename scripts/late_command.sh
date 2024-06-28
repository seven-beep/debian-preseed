#!/bin/sh -x
#
# This script is meant to be run as preseed/late_command.
#
# It does not use in-target as I found it unreliable to successfully end the installation.
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=610525
# chroot may be an option if commands need to be run from the target system.

if command -v lvs > /dev/null; then

   echo Remove the dummy volume if present.
   if lvs | grep dummy -q ; then
       VG=$(lvs | grep dummy | awk '{ print $2 }')
       for vg in "$VG" ; do
           umount "/dev/$vg/dummy"
           lvremove -y "/dev/$vg/dummy"
           sed -ri "s|^/dev/mapper/$vg-dummy.*||" /target/etc/fstab
       done
   fi

   echo Enable and configure a tmpfs for /tmp if it was not partitionned.
   if lvs | awk '{ print $2 }' | grep -Evq '^var$'; then
       cp -v /target/usr/share/systemd/tmp.mount /target/etc/systemd/system/tmp.mount
       # Enforce noexec on /tmp
       sed -ri 's/(Options.*)/\1,noexec/' /target/etc/systemd/system/tmp.mount
       mkdir -vp /target/etc/systemd/system/local-fs.target.wants/
       ln -fs /target/etc/systemd/system/tmp.mount /target/etc/systemd/system/local-fs.target.wants/tmp.mount
   fi
fi
