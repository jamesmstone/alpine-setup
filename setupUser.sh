#!/bin/sh
set -eo

generate_ssh() {
	ssh-keygen -t rsa -b 4096 -C "jamesmstone@users.noreply.github.com" -N "" -f /home/james/.ssh/id_rsa
	eval "$(ssh-agent -s)"
	ssh-add /home/james/.ssh/id_rsa
	cat /home/james/.ssh/id_rsa.pub | nc termbin.com 9999
}

# Add dotfiles
git clone https://github.com/jamesmstone/dotfiles.git  /home/james/dotfiles
# Install dotfiles
make -C /home/james/dotfiles

generate_ssh
