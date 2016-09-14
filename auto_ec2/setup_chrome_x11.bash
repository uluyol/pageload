#!/usr/bin/env bash

set -e

nodes=("$@")

for n in "${nodes[@]}"; do
	echo setup $n...
	ssh "$n" "\
		echo update && \
		sudo apt-get update -qq -y && \
		echo install deps && \
		sudo apt-get install -qq  -y \
			xvfb fluxbox x11vnc dbus libasound2 libqt4-dbus \
			libqt4-network libqtcore4 libqtgui4 libxss1 \
			libpython2.7 libqt4-xml libaudio2  fontconfig \
			liblcms1  libc6-i386 lib32gcc1 nano python3 \
			python-pip python-requests python-simplejson \
			python-websocket python-bs4 python-gobject-2 \
			tmux curl git && \
		echo add google signing key && \
		(wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
			| sudo apt-key add -) && \
		echo download chrome && \
		wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
		echo install chrome && \
		sudo dpkg -i google-chrome-stable_current_amd64.deb; \
		sudo apt-get install -qq -y -f && \
		sudo dpkg -i google-chrome-stable_current_amd64.deb && \
		echo remove junk && \
		rm -f google-chrome-stable_current_amd64.deb*"
done