#!/usr/bin/env bash

set -e

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR/cmd/internal:$TOPDIR

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
	echo usage: compute_page_kind_motivation.bash site_kinds_file run [run...] >&2
	exit 123
fi

site_kinds_file=$1; shift
all_runs=("$@")
devices=($(printf "%s\n" "${all_runs[@]}" | cut -d/ -f1 | sort | uniq))

resdir=results/page_kind_motivation

IFS=$'\n'
site_kinds=($(remove_comments_empty <"$site_kinds_file"))
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

mkdir -p "$procdir/site_kinds"
mkdir -p "$resdir" || true

for ((sk_i=0; sk_i < ${#site_kinds[@]}; sk_i++)); do
	dev_pids=()
	for dev in "${devices[@]}"; do
		(
			mkdir -p "$procdir/sites/${dev}_kind_${sk_i}/runs"
			runs=($(printf "%s\n" "${all_runs[@]}" | grep "^$dev" | sort -g -t/ -k2 | uniq))

			rm -f "$resdir/site_kinds/${dev}_kind_${sk_i}/page-iou" &>/dev/null || true
			rm -f "$resdir/site_kinds/${dev}_kind_${sk_i}/kind-iou" &>/dev/null || true
			mkdir -p "$resdir/site_kinds/${dev}_kind_${sk_i}"
			mkdir -p "$resdir/site_kinds/${dev}_kind_${sk_i}"
			for r in "${runs[@]}"; do
				echo $dev $r $sk_i / ${#site_kinds[@]}
				sites=()
				for s in ${site_kinds[sk_i]}; do
					s_clean=$(clean_url "$s")
					if [[ ! -d "$r.0/$(clean_url "$s")" ]] \
						|| [[ ! -f "$r.0/hars/$(clean_url "$s")" ]] \
						|| [[ ! -d "$r.1/$(clean_url "$s")" ]] \
						|| [[ ! -f "$r.1/hars/$(clean_url "$s")" ]]
					then
						# skip missing directories, not much we can do here
						continue
					fi
					sites+=("$s")
				done

				for ((si=0; si < ${#sites[@]}; si++)); do
					s=${sites[si]}
					s_clean=$(clean_url "$s")
					out=$(extract_records_index -preonload "$s" "$r.0" "$s_clean"	\
						| clip_after_iframes \
						| extracted2onoff.py)
					echo $s: $(jq ".online | length" <<<"$out") : $(jq ".offline | length" <<<"$out")
					extract_records_index -preonload "$s" "$r.0" "$s_clean"	\
						| clip_after_iframes \
						| extracted2onoff.py \
						| jq -r ".offline[].url" \
						| sort \
						> "$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.0.json"
					[[ ${PIPESTATUS[0]} -eq 0 ]]
					out=$(extract_records_index -preonload "$s" "$r.1" "$s_clean"	\
						| clip_after_iframes \
						| extracted2onoff.py)
					echo $s: $(jq ".online | length" <<<"$out") : $(jq ".offline | length" <<<"$out")
					extract_records_index -preonload "$s" "$r.1" "$s_clean" \
						| clip_after_iframes \
						| extracted2onoff.py \
						| jq -r ".offline[].url" \
						| sort \
						> "$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.1.json"
					[[ ${PIPESTATUS[0]} -eq 0 ]]
					iou.py \
						"$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.0.json" \
						"$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.1.json" \
						>> "$resdir/site_kinds/${dev}_kind_${sk_i}/page-iou"
					if [[ $si -ne 0 ]]; then
						iou.py \
							"$procdir/sites/${dev}_kind_${sk_i}/runs/$(clean_url "${sites[0]}")_offline_urls.0.json" \
							"$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.0.json" \
							>> "$resdir/site_kinds/${dev}_kind_${sk_i}/kind-iou"
						(
						echo -- 1 -- $s
						echo -- 2 -- ${sites[0]}
						comm -3 \
							<(comm -12 \
								"$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.0.json" \
								"$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.1.json") \
							<(comm -12 \
								"$procdir/sites/${dev}_kind_${sk_i}/runs/$(clean_url "${sites[0]}")_offline_urls.0.json" \
								"$procdir/sites/${dev}_kind_${sk_i}/runs/${s_clean}_offline_urls.0.json")
						) >"$resdir/site_kinds/${dev}_kind_${sk_i}/page-int-minus-kind-int"
					fi
				done
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
