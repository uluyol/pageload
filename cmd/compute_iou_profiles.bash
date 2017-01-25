#!/usr/bin/env bash

set -e 

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR/cmd/internal:$TOPDIR

remove_comments_empty() {
	sed 's/#.*$//g' | sed '/^$/d'
}

strjoin() {
	local IFS="$1"
	shift
	echo "$*"
}

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

results_dest=$1; shift
sites_file=$1; shift
IFS=,
runs=($1)
dev=$2
profiles=($3)
unset IFS

resdir="$results_dest/results/profiles_iou"
rm -rf "$resdir"
mkdir -p "$resdir"

IFS=$'\n'
sites=$(remove_comments_empty <"$sites_file")
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

get_stable_set() {
	local snap=$1; shift
	local profile=$1; shift
	local s=$1; shift

	local s_clean=$(clean_url $s)
	local depfiles=()
	local r
	mkdir "$procdir/${snap}.${profile}_${s_clean}"
	for load in 0 1; do
		if [[ ! -d "$dev/$snap.$profile.$load/$s_clean" || ! -f "$dev/$snap.$profile.$load/hars/$s_clean" ]]; then
			# missing directories, not much we can do here
			return 1
		fi

		extract_records_index -preonload "$s" "$dev/$snap.$profile.$load" "$s_clean" \
			| clip_after_iframes \
			| extracted_get_offline_dep_list.bash \
			| cut -d' ' -f1 \
			> "$procdir/${snap}.${profile}_${s_clean}/$load"

		depfiles+=("$procdir/${snap}.${profile}_${s_clean}/$load")
	done

	cat "${depfiles[@]}" \
		| sort \
		| uniq -c \
		| awk "\$1 >= ${#depfiles[@]} { print \$2 }" \
		> "$procdir/${snap}.${profile}_${s_clean}/stable_set"
}

process_site() {
	local snap=$1; shift
	local s=$1; shift
	local s_clean=$(clean_url $s)

	local p
	local inputs=()
	for p in "${profiles[@]}"; do
		echo $snap.$p $s
		get_stable_set $snap $p $s || continue

		inputs+=("$procdir/${snap}.${p}_${s_clean}/stable_set")
	done

	iou.py "${inputs[@]}" > "$resdir/${snap}_${s_clean}"
}

site_pids=()
for snap in "${runs[@]}"; do
	for s in $sites; do
		process_site $snap $s &
		site_pids+=($!)	
		while [[ $(jobs | wc -l) -ge 40 ]]; do
			sleep 3
		done
	done
done

fail=false
for j in ${site_pids[@]}; do
	if ! wait $j; then
		fail=true
	fi
done

if [[ $fail == "true" ]]; then
	exit 1
fi
