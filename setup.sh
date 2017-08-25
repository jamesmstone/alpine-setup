#!/bin/sh
set -eo

# enable community repo
echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories 
# update current packages
apk upgrade -U
# install new packages
apk add -U sudo docker git openrc openssh;
# run docker on boot
rc-update add docker boot

# Add user
adduser james -D;
