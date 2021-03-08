#!/bin/sh
set -eu # set  -e fail on error, -u treat unset variables as an error when substituting.

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

add() {
	apk add --update --no-progress "$@"
}


step 'Set up timezone'
setup-timezone -z Australia/Melbourne

step 'Set up networking'
cat > /etc/network/interfaces <<-EOF
	iface lo inet loopback
	iface eth0 inet dhcp
EOF
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

step 'set hostname'
echo "01.jamesst.one" > /etc/hostname # set hostname
hostname -F /etc/hostname # activate immediately

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Set up SSH'
setup-sshd -c openssh || true
add mosh

step 'Enable services'
rc-update add acpid default
rc-update add chronyd default
rc-update add crond default
rc-update add net.eth0 default
rc-update add net.lo boot
rc-update add termencoding boot
rc-update add docker boot

step 'Add X'
setup-xorg-base || true
add dwm \
  firefox \
  x2goserver \
  x2goserver-openrc \
  perl-switch # a missing dependency of x2goserver

sed -i '/.*X11Forwarding.*/ c X11Forwarding yes' /etc/ssh/sshd_config

step 'Configure crontab'
mkdir -p /etc/periodic/reboot
echo "@reboot					run-parts /etc/periodic/reboot" >> /var/spool/cron/crontabs/root
step 'Add default user'
adduser james -D -G wheel;
addgroup james x2gouser;
sed -i s/james:!/"james:*"/g /etc/shadow # https://github.com/camptocamp/puppet-accounts/issues/35#issuecomment-366412237
echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel
addgroup james docker; # Add default user to docker group, see: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user

# add ssh access from all my github keys
sudo -u james mkdir -p /home/james/.ssh
sudo -u james wget -O - https://github.com/jamesmstone.keys | sudo -u james tee -a /home/james/.ssh/authorized_keys


# Add dotfiles
sudo -u james git clone https://github.com/jamesmstone/dotfiles.git  /home/james/dotfiles
sudo -u james git -C /home/james/dotfiles/ remote set-url origin git@github.com:jamesmstone/dotfiles.git
# Install dotfiles
sudo -u james make -C /home/james/dotfiles

