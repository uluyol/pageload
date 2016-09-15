#!/usr/bin/env bash

set -e

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR

clean_url() {
	local site=$1
	if [[ ${site: -1} == "/" ]]; then
		site=${site:0: -1}
	fi
	if [[ $site =~ ^http:// ]]; then
		site=${site:7}
	elif [[ $site =~ ^https:// ]]; then
		site=${site:8}
	fi
	if [[ $site =~ ^www\. ]]; then
		site=${site:4}
	fi
	echo "$site"
}

# reads network events on stdin
get_sorted_offline_deps() {
	local site="$1"
	local iterdir="$2"
	local savedir="$iterdir/$(clean_url "$site")"

	combined=$(list_resources "$savedir" | sort | uniq)
	index_urls=$(get_index -urls "$site" "$savedir")
	index_last_url=$(tail -n1 <<<"$index_urls")
	index_html=$(get_index "$site" "$savedir")
	online=$(_internal_get_online_deps.py "$index_last_url" <<<"$index_html")

	to_remove=$(cat <(echo "$index_urls") <(echo "$online") | sort | uniq)

	comm -23 <(echo "$combined") <(echo "$to_remove")
}

get_sorted_offline_deps "$1" "$2"