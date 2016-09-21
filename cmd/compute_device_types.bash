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
dev0=$2
devs=($3)
unset IFS

resdir="$results_dest/results/device_types"
rm -rf "$resdir"
mkdir -p "$resdir"

IFS=$'\n'
sites=$(remove_comments_empty <"$sites_file")
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

get_stable_set() {
	local dev=$1
	local s=$s

	local s_clean=$(clean_url $s)
	local depfiles=()
	local r
	mkdir "$procdir/${dev}_${s_clean}"
	for r in "${runs[@]}"; do
		if [[ ! -d "$dev/$r/$s_clean" || ! -f "$dev/$r/hars/$s_clean" ]]; then
			# missing directories, not much we can do here
			return 1
		fi

		extract_records_index -preonload "$s" "$dev/$r" "$s_clean" \
			| clip_after_iframes \
			| extracted_get_offline_dep_list.bash \
			| cut -d' ' -f1 \
			> "$procdir/${dev}_${s_clean}/$r"

		depfiles+=("$procdir/${dev}_${s_clean}/$r")
	done
	cat "${depfiles[@]}" \
		| sort \
		| uniq -c \
		| awk "\$1 >= ${#depfiles[@]} { print \$2 }" \
		> "$procdir/${dev}_${s_clean}/stable_set"
}

process_site() {
	local s=$1

	s_clean=$(clean_url $s)
	# continue's below are so that we skip
	# site/snapshot pairs that contain missing
	# data
	echo $dev0 $s
	get_stable_set $dev0 $s || continue

	local d
	for d in "${devs[@]}"; do
		echo $d $s
		get_stable_set $d $s || continue
		n=$(wc -l <"$procdir/${d}_${s_clean}/stable_set")

		local inputs=(
			"$procdir/${dev0}_${s_clean}/stable_set"
			"$procdir/${d}_${s_clean}/stable_set"
		)

		local ni=$(
			cat "${inputs[@]}" \
				| sort \
				| uniq -c \
				| awk '$1 == 2 { print $2 }' \
				| wc -l
		)
		local nu=$(cat "${inputs[@]}" | sort | uniq | wc -l)

		if [[ $nu -eq 0 ]]; then
			echo 1 > "$resdir/${d}_${dev0}_${s_clean}"
		else
			python -c "print (float($ni) / $nu)" \
				> "$resdir/${d}_${dev0}_${s_clean}"
		fi
	done
}

site_pids=()
for s in $sites; do
	process_site $s &
	site_pids+=($!)	
	while [[ $(jobs | wc -l) -ge 40 ]]; do
		sleep 3
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
