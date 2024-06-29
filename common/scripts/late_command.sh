#!/bin/sh
#
# This script is meant to be run as preseed/late_command.
#
# It does not use in-target as I found it unreliable to successfully end the installation.
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=610525
# chroot may be an option if commands need to be run from the target system.
set -ex

logger Executing late_command.sh

if command -v lvs > /dev/null; then

   if lvs | grep dummy -q ; then
       logger Remove the dummy volume
       VG=$(lvs | grep dummy | awk '{ print $2 }')
       for vg in "$VG" ; do
           umount "/dev/$vg/dummy"
           lvremove -y "/dev/$vg/dummy"
           sed -ri "s|^/dev/mapper/$vg-dummy.*||" /target/etc/fstab
       done
   fi

   if lvs | awk '{ print $2 }' | grep -Evq '^var$'; then
       logger Enable and configure a tmpfs for /tmp as it was not partitionned
       cp -v /target/usr/share/systemd/tmp.mount /target/etc/systemd/system/tmp.mount
       # Enforce noexec on /tmp
       sed -ri 's/(Options.*)/\1,noexec/' /target/etc/systemd/system/tmp.mount
       mkdir -vp /target/etc/systemd/system/local-fs.target.wants/
       ln -fs /target/etc/systemd/system/tmp.mount /target/etc/systemd/system/local-fs.target.wants/tmp.mount
   fi
fi

logger Enforcing https in /target/etc/apt/sources.list
sed -i 's|http://|https://|g' /target/etc/apt/sources.list

# The installed should may have created only one user, so at this point,
# it seems safe to assume that:
user=$(ls /home)

if [[ -f /private/authorized_keys ]]; then
    logger Setting up authorized_keys

    # Assuming that you want the keys in for your user if you created it,
    # or for root if you didn't created it.
    if [[ -n "$user" ]]; then
        mkdir -p "/home/$user/.ssh"
        chmod 700 "/home/$user/.ssh"
        mv /private/authorized_keys "/home/$user/.ssh/"
        chmod 600 "/home/$user/.ssh/authorized_keys"
        chown "$user:$user" -R "/home/$user/.ssh"
    else
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        mv /private/authorized_keys /root/.ssh/
        chmod 600 /root/.ssh/authorized_keys
    fi
fi
