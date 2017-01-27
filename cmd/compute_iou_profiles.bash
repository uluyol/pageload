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
echo $procdir
#trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

get_stable_set() {
	local snap=$1; shift
	local profile=$1; shift
	local s=$1; shift

	local s_clean=$(clean_url $s)
	local r
	mkdir "$procdir/${snap}.${profile}_${s_clean}"
	for load in 0 1; do
		if [[ ! -d "$dev/$snap.$profile.$load/$s_clean" || ! -f "$dev/$snap.$profile.$load/hars/$s_clean" ]]; then
			# missing directories, not much we can do here
			return 1
		fi

		extract_records_index -preonload "$s" "$dev/$snap.$profile.$load" "$s_clean" \
			| extracted2onoff.py \
			> "$procdir/${snap}.${profile}_${s_clean}/$load"
	done

	local onoff=$(
		cat "$procdir/${snap}.${profile}_${s_clean}"/{0,1} \
			| jq -s . \
			| unfair_intersection.py
	)

	jq -r '.online[].url' <<<"$onoff" | sort | uniq \
		> "$procdir/${snap}.${profile}_${s_clean}/stable_online"
	jq -r '.offline[].url' <<<"$onoff" | sort | uniq \
		> "$procdir/${snap}.${profile}_${s_clean}/stable_offline"
	cat "$procdir/${snap}.${profile}_${s_clean}"/stable_{online,offline} \
		> "$procdir/${snap}.${profile}_${s_clean}/stable_all"
}

process_site() {
	local snap=$1; shift
	local s=$1; shift
	local s_clean=$(clean_url $s)

	local p
	local on_inputs=()
	local off_inputs=()
	local all_inputs=()
	for p in "${profiles[@]}"; do
		echo $snap.$p $s
		get_stable_set $snap $p $s || continue

		on_inputs+=("$procdir/${snap}.${p}_${s_clean}/stable_online")
		off_inputs+=("$procdir/${snap}.${p}_${s_clean}/stable_offline")
		all_inputs+=("$procdir/${snap}.${p}_${s_clean}/stable_all")
	done

	iou.py "${on_inputs[@]}" > "$resdir/online_${snap}_${s_clean}"
	iou.py "${off_inputs[@]}" > "$resdir/offline_${snap}_${s_clean}"
	iou.py "${all_inputs[@]}" > "$resdir/all_${snap}_${s_clean}"
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


for ((i=2; i < ${#runs[@]}; i++)); do
	for s in $sites; do
		(
		s_clean=$(clean_url $s)
		multistep_off_inputs=()
		for p in "${profiles[@]}"; do
			stables=()
			for snap in ${runs[i-2]} ${runs[i-1]} ${runs[i]}; do
				stables+=("$procdir/${snap}.${p}_${s_clean}/stable_offline")
			done
			cat "${stables[@]}" \
				| sort \
				| uniq -c \
				| awk '$1 >= 3 {print $2;}' \
				> "$procdir/${runs[i]}.${p}_${s_clean}/stable_multistep_offline"
			multistep_off_inputs+=("$procdir/${runs[i]}.${p}_${s_clean}/stable_multistep_offline")
		done
		for ((ii=0; ii < ${#multistep_off_inputs[@]}; ii++)); do
			for ((ij=ii+1; ij < ${#multistep_off_inputs[@]}; ij++)); do
				iou.py "${multistep_off_inputs[ii]}" "${multistep_off_inputs[ij]}" \
					> "$resdir/combined_pairwise_offline_${runs[i]}_${s_clean}.$ii.$ij"
			done
		done
		iou.py "${multistep_off_inputs[@]}" > "$resdir/combined_offline_${runs[i]}_${s_clean}"
		) &
	done
done

wait
