#!/usr/bin/env bash

set -e

GET_CONTENT_TYPES=${GET_CONTENT_TYPES:-false}
TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR:$TOPDIR/cmd/internal

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
	echo "$site" \
		| sed \
			-e 's,/,_,g' \
			-e 's,?,__,g' \
			-e 's,%,__,g' \
			-e 's,&,__,g'
}

# reads network events on stdin
get_sorted_offline_deps() {
	local site="$1"
	local iterdir="$2"
	local get_content_types=$3

	local savedir="$iterdir/$(clean_url "$site")"

	local list_resources_args=""
	if [[ $get_content_types == "true" ]]; then
		list_resources_args="-types"
	fi

	index_urls=$(get_index -urls "$site" "$savedir")
	index_last_url=$(tail -n1 <<<"$index_urls")
	index_html=$(get_index "$site" "$savedir")
	combined=$(list_resources $list_resources_args "$index_last_url" "$savedir" | sort | uniq)
	online=$(_internal_get_online_deps.py "$index_last_url" <<<"$index_html")

	to_remove=$(cat <(echo "$index_urls") <(echo "$online") | sort | uniq)

	_setops_ignore_types.py setdiff <(echo "$combined") <(echo "$to_remove")
}

get_sorted_offline_deps "$1" "$2" "$GET_CONTENT_TYPES"