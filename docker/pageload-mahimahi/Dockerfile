FROM ubuntu:14.04

RUN apt-get update -qq -y && \
	apt-get install -qq -y software-properties-common python-software-properties wget && \
	add-apt-repository ppa:keithw/mahimahi && \
	wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
		| apt-key add - && \
	echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
		>> /etc/apt/sources.list.d/google.list && \
	apt-get update -qq -y && \
	apt-get install -qq  -y \
		xvfb fluxbox x11vnc dbus libasound2 libqt4-dbus \
		libqt4-network libqtcore4 libqtgui4 libxss1 \
		libpython2.7 libqt4-xml libaudio2  fontconfig \
		liblcms1  libc6-i386 lib32gcc1 nano python3 \
		python-pip python-requests python-simplejson \
		python-websocket python-bs4 python-gobject-2 \
		tmux curl git mahimahi google-chrome-stable

RUN apt-get install -qq -y bsdmainutils libpipeline1 man-db dbus-x11 jq

RUN useradd -d /home/mahimahi -m mahimahi && \
	gpasswd -a mahimahi adm && \
	gpasswd -a mahimahi dialout && \
	gpasswd -a mahimahi cdrom && \
	gpasswd -a mahimahi floppy && \
	gpasswd -a mahimahi sudo && \
	gpasswd -a mahimahi audio && \
	gpasswd -a mahimahi dip && \
	gpasswd -a mahimahi video && \
	gpasswd -a mahimahi plugdev && \
	gpasswd -a mahimahi netdev

ENV DBUS_SESSION_BUS_ADDRESS=/dev/null 

USER mahimahi