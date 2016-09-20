#!/usr/bin/env bash

set -e

WINDOW_SIZE=3

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR/cmd/internal

remove_comments_empty() {
	sed 's/#.*$//g' | sed '/^$/d'
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

if [[ $# -lt 2 ]]; then
	echo usage: compute_acc.bash sites_file run [run...] >&2
	exit 123
fi

sites_file=$1; shift
all_runs=("$@")
devices=($(printf "%s\n" "${all_runs[@]}" | cut -d/ -f1 | sort | uniq))

resdir=results/accuracy

sites=$(remove_comments_empty <"$sites_file")

procdir=$(mktemp -d)
#trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

mkdir -p "$procdir/sites"
mkdir -p "$resdir" || true

for s in $sites; do
	s_clean=$(clean_url "$s")
	dev_pids=()
	for dev in "${devices[@]}"; do
		(
			echo $s $dev
			mkdir -p "$procdir/sites/${dev}_${s_clean}/runs"
			runs=($(printf "%s\n" "${all_runs[@]}" | grep "^$dev" | sort -g -t/ -k2 | uniq))

			dep_dirs=()
			for r in "${runs[@]}"; do
				if [[ ! -d "$r.0/$(clean_url "$s")" ]] \
					|| [[ ! -f "$r.0/hars/$(clean_url "$s")" ]] \
					|| [[ ! -d "$r.1/$(clean_url "$s")" ]] \
					|| [[ ! -f "$r.1/hars/$(clean_url "$s")" ]]
				then
					# skip missing directories, not much we can do here
					continue
				fi
				extract_records_index -preonload "$s" "$r.0" "$(clean_url "$s")" \
					| clip_after_iframes \
					| extracted2onoff.py \
					> "$procdir/sites/${dev}_${s_clean}/runs/onoff.0.json"
				[[ ${PIPESTATUS[0]} -eq 0 ]]
				extract_records_index -preonload "$s" "$r.1" "$(clean_url "$s")" \
					| clip_after_iframes \
					| extracted2onoff.py \
					> "$procdir/sites/${dev}_${s_clean}/runs/onoff.1.json"
				[[ ${PIPESTATUS[0]} -eq 0 ]]
				dep_dirs+=("$procdir/sites/${dev}_${s_clean}/runs")

				jq -r "(.online | length | tostring) + \":\" + (.offline | length | tostring)" <"$procdir/sites/${dev}_${s_clean}/runs/onoff.0.json"
			done

			mkdir -p "$resdir/sites/${dev}_${s_clean}"
			rm -rf "$resdir/sites/${dev}_${s_clean}/missed"
			rm -rf "$resdir/sites/${dev}_${s_clean}/extra"
			mkdir "$resdir/sites/${dev}_${s_clean}/missed"
			mkdir "$resdir/sites/${dev}_${s_clean}/extra"
			for ((i=WINDOW_SIZE; i < ${#dep_dirs[@]}; i++)); do

				predictable=$(
					cat \
						"${dep_dirs[i]}/onoff.0.json" \
						"${dep_dirs[i]}/onoff.1.json" \
						| jq -s . \
						| unfair_intersection.py
				)
				echo "$predictable" >"$resdir/sites/${dev}_${s_clean}/pred-set"

				n_predictable_off=$(jq ".offline | length" <<<"$predictable")
				n_predictable_on=$(jq ".online | length" <<<"$predictable")
				n_predictable=$((n_predictable_off + n_predictable_on))

				# Compute fraction of resources and bytes captured in
				# predictable set compared to all.
				(
					n_all=$(jq "[.online[], .offline[]] | length" <"${dep_dirs[i]}/onoff.0.json")
					b_all=$(
						jq "[.online[].bytes, .offline[].bytes] | add" \
							<"${dep_dirs[i]}/onoff.0.json"
					)
					b_predictable=$(
						jq "[.online[].bytes, .offline[].bytes] | add" \
							<<<"$predictable"
					)
					# if .online or offline is empty, we will get null
					# for byte counts, so fix them here
					if [[ $b_all == "null" ]]; then
						b_all=0
					fi
					if [[ $b_predictable == "null" ]]; then
						b_predictable=0
					fi

					python -c "print (float($n_predictable) / max($n_all, 1))" \
						>>"$resdir/sites/${dev}_${s_clean}/bytes-ratio"
					python -c "print (float($b_predictable) / max($b_all, 1))" \
						>>"$resdir/sites/${dev}_${s_clean}/count-ratio"
				)

				# Compute online missed extra
				#
				# We have two back-to-back snapshots, consider one to be
				# a load on the server side, and one on the client.
				# Use the resources downloaded on the server as the set
				# of dependencies sent to the client.
				(
					echo 0 >> "$resdir/sites/${dev}_${s_clean}/missed/online"
					n_sent=$(jq ".offline | length" <"${dep_dirs[i]}/onoff.1.json")
					python -c "print (float($n_sent - $n_predictable_off) / max($n_predictable, 1))" \
						>> "$resdir/sites/${dev}_${s_clean}/extra/online"
				)

				# Compute offline and hybrid missed extra
				#
				# Use previous timesteps to predict the upcoming one
				# using the intersection of the previous loads without
				# the in-HTML resources.
				# For hybrid, include online deps from predictable set
				# since we can discover those on-the-fly.
				(
					win=$(
						for ((j=i-WINDOW_SIZE; j < i; j++)); do
							cat "${dep_dirs[j]}"/onoff.{0,1}.json
						done | jq -s . | unfair_intersection.py
					)
					overlap=$(
						printf "%s\n" "$predictable" "$win" \
							| jq -s . \
							| unfair_intersection.py
					)
					nw=$(jq ".offline | length" <<< "$win")
					no_on=$(jq ".online | length" <<<"$overlap")
					no_off=$(jq ".offline | length" <<<"$overlap")
					python -c "print (float($nw - $no_off) / max($n_predictable, 1))" \
						>> "$resdir/sites/${dev}_${s_clean}/extra/offline"
					python -c "print (float($n_predictable - $no_off) / max($n_predictable, 1))" \
						>> "$resdir/sites/${dev}_${s_clean}/missed/offline"
					nw_online=$(jq ".online | length" <<<"$overlap")
					nw=$(( nw + nw_online ))
					no=$(( no_on + no_off ))
					python -c "print (float($nw - $no) / max($n_predictable, 1))" \
						>> "$resdir/sites/${dev}_${s_clean}/extra/hybrid"
					python -c "print (float($n_predictable - $no) / max($n_predictable, 1))" \
						>> "$resdir/sites/${dev}_${s_clean}/missed/hybrid"
				)
			done
		) &
		dev_pids+=($!)
	done

	all_success=1
	for p in ${dev_pids[@]}; do
		if ! wait $p; then
			all_success=0
		fi
	done
	(( all_success == 1 ))
done
