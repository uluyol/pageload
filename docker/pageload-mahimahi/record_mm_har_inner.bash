#!/usr/bin/env bash

chrome_startup_wait=$1
second_wait=$2
har_out=$3
site="$4"
user_agent="$5"
dims="$6"

google-chrome-unstable \
				--ignore-certificate-errors \
				--user-agent "$user_agent" \
				--window 400x800 \
				--user-data-dir=/tmp/fresh \
				--disable-extensions \
				--remote-debugging-port=9922 \
				--disable-logging \
				about:blank &
pid=$!
start=$(date +%s) || exit 1
sleep $chrome_startup_wait
timeout $second_wait \
	chrome-har-capturer \
		-t localhost \
		-p 9922 \
		-a "$user_agent" \
		-o "$har_out" \
		"$site" || exit 1
kill -9 $pid
