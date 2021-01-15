#!/bin/sh

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
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

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Set up SSH'
setup-sshd -c dropbear


step 'Enable services'
rc-update add acpid default
rc-update add chronyd default
rc-update add crond default
rc-update add net.eth0 default
rc-update add net.lo boot
rc-update add termencoding boot
rc-update add docker boot

step 'Add X'
setup-xorg-base
apk add --update --no-progress \
  dwm \
  firefox \
  vino \
  xrdp

# start on boot
rc-update add xrdp
rc-update add xrdp-sesman
rc-update add vino

step 'Add default user'
adduser james -D -G wheel;
echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel

# add ssh access from all my github keys
sudo -u james mkdir -p /home/james/.ssh
sudo -u james wget -O - https://github.com/jamesmstone.keys | sudo -u james tee -a /home/james/.ssh/authorized_keys


# Add dotfiles
sudo -u james git clone https://github.com/jamesmstone/dotfiles.git  /home/james/dotfiles
# Install dotfiles
sudo -u james make -C /home/james/dotfiles


