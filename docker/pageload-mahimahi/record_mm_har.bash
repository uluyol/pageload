#!/usr/bin/env bash

first_wait=$1
chrome_startup_wait=$2
second_wait=$3
mm_out="$4"
har_out="$5"
site="$6"
user_agent="$7"
dims="$8"

timeout $first_wait \
	xvfb-run --server-args='-screen 0, 1920x1080x16' \
		dbus-launch --exit-with-session \
			google-chrome-unstable \
			--ignore-certificate-errors \
			--user-agent "$user_agent" \
			--window $dims \
			--user-data-dir=/tmp/fresh \
			http://example.com
# this timeout shouldn't trigger, it's just a backup
# to keep making progress if something terrible
# happens
timeout 400 \
xvfb-run --server-args='-screen 0, 1920x1080x16' \
	dbus-launch --exit-with-session \
		mm-webrecord "$mm_out" \
			record_mm_har_inner.bash "$chrome_startup_wait" "$second_wait" \
				"$har_out" "$site" "$user_agent" $dims
