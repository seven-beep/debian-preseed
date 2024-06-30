#!/bin/sh
#
# This script is meant to be run as preseed/late_command.
#
# It does not use in-target as I found it unreliable to successfully end the installation.
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=610525
# chroot may be an option if commands need to be run from the target system.
set -ex

logger "Executing late_command.sh"

if command -v lvs > /dev/null; then

   if lvs | grep dummy -q ; then
       logger "Remove the dummy volume"
       # Notice that the lv dummy should not have a mount point,
       # Otherwise we should also patch /etc/fstab.
       VG=$(lvs | grep dummy | awk '{ print $2 }')
       for vg in $VG ; do
           lvremove -y "/dev/$vg/dummy"
       done
   fi

   if lvs | awk '{ print $2 }' | grep -Evq '^var$'; then
       logger "Enable and configure a tmpfs for /tmp as it was not partitionned"
       cp -v /target/usr/share/systemd/tmp.mount /target/etc/systemd/system/tmp.mount
       # Enforce noexec on /tmp
       sed -ri 's/(Options.*)/\1,noexec/' /target/etc/systemd/system/tmp.mount
       mkdir -vp /target/etc/systemd/system/local-fs.target.wants/
       ln -fs /target/etc/systemd/system/tmp.mount /target/etc/systemd/system/local-fs.target.wants/tmp.mount
   fi
fi

logger "Enforcing https in /target/etc/apt/sources.list"
sed -i 's|http://|https://|g' /target/etc/apt/sources.list

# Aprioris, there is only one user in /home right now.
user=$(awk -F':' '$6 ~ "^/home" { print $1 }' /etc/passwd)

if [ -f /private/authorized_keys ]; then
    logger "Setting up authorized_keys"

    # Assuming that you want the keys in for your user if you created it,
    # or for root if you didn't created it.
    if [ -n "$user" ]; then
        mkdir --parent --verbose --directory "/target/home/$user/.ssh"
        chmod 0700 "/target/home/$user/.ssh"
        mv --verbose /private/authorized_keys "/target/home/$user/.ssh/"
        chmod 0600 "/target/home/$user/.ssh/"
        chown "$user:$user" -R "/target/home/$user/.ssh"
        logger "Enabling passwordless sudo for $user"
        echo "$user ALL=(ALL) NOPASSWD: ALL" >  "/target/etc/sudoers.d/$user";
    else
        mkdir --parent --verbose /target/root/.ssh
        chmod 0700 /target/root/.ssh
        mv --verbose /private/authorized_keys /target/root/.ssh/authorized_keys
        chmod 0600 /target/root/.ssh/authorized_keys
    fi
fi

if [ -f /private/default/keyboard ]; then
    logger "Reconfiguring keyboard"
    mv --verbose /private/default/keyboard /target/etc/default/keyboard
    in-target dpkg-reconfigure --frontend noninteractive keyboard-configuration
fi

if [ -f /private/default/console-setup ]; then
    logger "Reconfiguring console-setup"
    mv --verbose /private/default/console-setup /target/etc/default/console-setup
    in-target dpkg-reconfigure --frontend noninteractive console-setup
fi

if [ -f /private/default/grub ]; then
    logger "Reconfiguring grub"
    mv --verbose /private/default/grub /target/etc/default/grub
    in-target update-grub
fi
