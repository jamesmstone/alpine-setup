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

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Set up SSH'
setup-sshd -c dropbear || true
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
  xorgxrdp \
  xrdp \
  x2goserver \
  x2goserver-openrc

sed -i -e '/# exec xterm/c\exec dwm' /etc/xrdp/startwm.sh
cat <<EOF > /etc/xrdp/xrdp.ini
[Globals]
; xrdp.ini file version number
ini_version=1

; fork a new process for each incoming connection
fork=true

; ports to listen on, number alone means listen on all interfaces
; 0.0.0.0 or :: if ipv6 is configured
; space between multiple occurrences
;
; Examples:
;   port=3389
;   port=unix://./tmp/xrdp.socket
;   port=tcp://.:3389                           127.0.0.1:3389
;   port=tcp://:3389                            *:3389
;   port=tcp://<any ipv4 format addr>:3389      192.168.1.1:3389
;   port=tcp6://.:3389                          ::1:3389
;   port=tcp6://:3389                           *:3389
;   port=tcp6://{<any ipv6 format addr>}:3389   {FC00:0:0:0:0:0:0:1}:3389
;   port=vsock://<cid>:<port>
port=3389

; 'port' above should be connected to with vsock instead of tcp
; use this only with number alone in port above
; prefer use vsock://<cid>:<port> above
use_vsock=false

; regulate if the listening socket use socket option tcp_nodelay
; no buffering will be performed in the TCP stack
tcp_nodelay=true

; regulate if the listening socket use socket option keepalive
; if the network connection disappear without close messages the connection will be closed
tcp_keepalive=true

; set tcp send/recv buffer (for experts)
#tcp_send_buffer_bytes=32768
#tcp_recv_buffer_bytes=32768

; security layer can be 'tls', 'rdp' or 'negotiate'
; for client compatible layer
security_layer=negotiate

; minimum security level allowed for client for classic RDP encryption
; use tls_ciphers to configure TLS encryption
; can be 'none', 'low', 'medium', 'high', 'fips'
crypt_level=high

; X.509 certificate and private key
; openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 365
certificate=
key_file=

; set SSL protocols
; can be comma separated list of 'SSLv3', 'TLSv1', 'TLSv1.1', 'TLSv1.2', 'TLSv1.3'
ssl_protocols=TLSv1.2, TLSv1.3
; set TLS cipher suites
#tls_ciphers=HIGH

; Section name to use for automatic login if the client sends username
; and password. If empty, the domain name sent by the client is used.
; If empty and no domain name is given, the first suitable section in
; this file will be used.
autorun=

allow_channels=true
allow_multimon=true
bitmap_cache=true
bitmap_compression=true
bulk_compression=true
use_compression=true
#hidelogwindow=true
max_bpp=128
new_cursors=true
; fastpath - can be 'input', 'output', 'both', 'none'
use_fastpath=both
; when true, userid/password *must* be passed on cmd line
#require_credentials=true
; You can set the PAM error text in a gateway setup (MAX 256 chars)
#pamerrortxt=change your password according to policy at http://url

[Logging]
LogFile=xrdp.log
LogLevel=DEBUG
EnableSyslog=true
SyslogLevel=DEBUG
; LogLevel and SysLogLevel could by any of: core, error, warning, info or debug

[Channels]
; Channel names not listed here will be blocked by XRDP.
; You can block any channel by setting its value to false.
; IMPORTANT! All channels are not supported in all use
; cases even if you set all values to true.
; You can override these settings on each session type
; These settings are only used if allow_channels=true
rdpdr=true
rdpsnd=true
drdynvc=true
cliprdr=true
rail=true
xrdpvr=true
tcutils=true

; for debugging xrdp, in section xrdp1, change port=-1 to this:
#port=/tmp/.xrdp/xrdp_display_10

; for debugging xrdp, add following line to section xrdp1
#chansrvport=/tmp/.xrdp/xrdp_chansrv_socket_7210


;
; Session types
;

; Some session types such as Xorg, X11rdp and Xvnc start a display server.
; Startup command-line parameters for the display server are configured
; in sesman.ini. See and configure also sesman.ini.
[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20
EOF


# start on boot
rc-update add xrdp
rc-update add xrdp-sesman

step 'Configure crontab'
mkdir -p /etc/periodic/reboot
echo "@reboot					run-parts /etc/periodic/reboot" >> /var/spool/cron/crontabs/root
step 'Add default user'
adduser james -D -G wheel;
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

