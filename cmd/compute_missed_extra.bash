#!/usr/bin/env bash

set -e

FILTER_ADS=${FILTER_ADS:-0}
WINDOW_SIZE=3
ALLOW_MISSING=0

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR/cmd/internal:$TOPDIR:$TOPDIR/cmd/filterads

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

intersection() {
	local N=$1

	sort \
		| uniq -c \
		| awk "\$1 >= $N { print \$2 }"
}

get_important() {
	egrep '(javascript|ecmascript|html|css)'
}

if [[ $# -lt 2 ]]; then
	echo usage: compute_missed_extra.bash results_dest sites_file run [run...] >&2
	exit 123
fi

results_dest=$1; shift
sites_file=$1; shift
all_runs=("$@")
devices=($(printf "%s\n" "${all_runs[@]}" | cut -d/ -f1 | sort | uniq))

resdir="$results_dest/results/missed_extra"

sites=$(remove_comments_empty <"$sites_file")

procdir=$(mktemp -d)
#trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT
echo $procdir

if [[ $FILTER_ADS -eq 1 ]]; then
	"$TOPDIR/cmd/filterads/runserver.bash" --tracking &
	pid=$!
	trap "kill -9 $pid" SIGTERM SIGQUIT EXIT SIGINT

	while ! (lsof -n -iTCP:3000 | grep LISTEN) &>/dev/null; do
		sleep 1
	done
fi

mkdir -p "$procdir/sites"
mkdir -p "$resdir" || true

process_site() {
	local s="$1"
	local s_clean=$(clean_url "$s")
	local dev_pids=()
	local dev
	local r
	for dev in "${devices[@]}"; do
		#(
		mkdir -p "$procdir/sites/${dev}_${s_clean}/runs"
		runs=($(printf "%s\n" "${all_runs[@]}" | grep "^$dev" | sort -g -t/ -k2 | uniq))

		local dep_files=()
		local online_dep_files=()
		local server_offline_dep_files=()
		local filtered_depcount_ratios_overall=()
		local filtered_depcount_ratios_offline=()
		local filtered_depbytes_ratios_overall=()
		local filtered_depbytes_ratios_offline=()

		local b2b_depcount_ratios_overall=()
		local b2b_depcount_ratios_offline=()
		local b2b_depbytes_ratios_overall=()
		local b2b_depbytes_ratios_offline=()
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
				| clip_after_iframes > "$procdir/sites/${dev}_${s_clean}/runs/records_index.0.json"
			[[ ${PIPESTATUS[0]} -eq 0 ]]
			extract_records_index -preonload "$s" "$r.1" "$(clean_url "$s")" \
				| clip_after_iframes > "$procdir/sites/${dev}_${s_clean}/runs/records_index.1.json"
			[[ ${PIPESTATUS[0]} -eq 0 ]]
			args=""
			if [[ $FILTER_ADS -eq 1 ]]; then
				args="--filter"
			fi
			local ratios=($(
				get_run_deps_filtered_counts.py \
					$args \
					"$procdir/sites/${dev}_${s_clean}/runs" \
					"${r//\//.}"
			))
			filtered_depcount_ratios_overall+=(${ratios[0]})
			filtered_depcount_ratios_offline+=(${ratios[1]})
			filtered_depbytes_ratios_overall+=(${ratios[2]})
			filtered_depbytes_ratios_offline+=(${ratios[3]})

			b2b_depcount_ratios_overall+=(${ratios[4]})
			b2b_depcount_ratios_offline+=(${ratios[5]})
			b2b_depbytes_ratios_overall+=(${ratios[6]})
			b2b_depbytes_ratios_offline+=(${ratios[7]})

			dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}")
			online_dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/online-${r//\//.}")
			server_offline_dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/server-offline-${r//\//.}")

			echo $s: $(wc -l <"$procdir/sites/${dev}_${s_clean}/runs/online-${r//\//.}") : $(wc -l <"$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}")
		done

		if (( ${#dep_files[@]} == 0 )); then
			# skip dev/sites with no data
			continue
		fi

		mkdir -p "$resdir/sites/${dev}_${s_clean}/lists"
		rm -f "$resdir/sites/${dev}_${s_clean}/missed"
		rm -f "$resdir/sites/${dev}_${s_clean}/extra"
		rm -f "$resdir/sites/${dev}_${s_clean}/missed-offline"
		rm -f "$resdir/sites/${dev}_${s_clean}/extra-offline"
		rm -f "$resdir/sites/${dev}_${s_clean}/missed-server"
		rm -f "$resdir/sites/${dev}_${s_clean}/extra-server"

		printf "%s\n" "${filtered_depcount_ratios_overall[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/depcount-ratio-overall"
		printf "%s\n" "${filtered_depcount_ratios_offline[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/depcount-ratio-offline"
		printf "%s\n" "${filtered_depbytes_ratios_overall[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/depbytes-ratio-overall"
		printf "%s\n" "${filtered_depbytes_ratios_offline[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/depbytes-ratio-offline"

		printf "%s\n" "${b2b_depcount_ratios_overall[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/b2b-depcount-ratio-overall"
		printf "%s\n" "${b2b_depcount_ratios_offline[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/b2b-depcount-ratio-offline"
		printf "%s\n" "${b2b_depbytes_ratios_overall[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/b2b-depbytes-ratio-overall"
		printf "%s\n" "${b2b_depbytes_ratios_offline[@]}" \
			> "$resdir/sites/${dev}_${s_clean}/b2b-depbytes-ratio-offline"

		for ((i=WINDOW_SIZE; i < ${#dep_files[@]}; i++)); do
			(
				for ((j=i-WINDOW_SIZE; j < i; j++)); do
					cat "${dep_files[j]}"
				done
			) | intersection "$((WINDOW_SIZE-ALLOW_MISSING))" \
				| sort \
				| uniq \
				> "$procdir/sites/${dev}_${s_clean}/deps_window_offline_$i"

			(
				for ((j=i-WINDOW_SIZE; j < i; j++)); do
					cat "${dep_files[j]}"
				done
			) | intersection "$((WINDOW_SIZE-ALLOW_MISSING))" \
				| cat - "${online_dep_files[i]}" \
				| sort \
				| uniq \
				> "$procdir/sites/${dev}_${s_clean}/deps_window_$i"

			cat "${dep_files[i]}" "${online_dep_files[i]}" \
				| sort \
				| uniq \
				> "$procdir/sites/${dev}_${s_clean}/deps_test_$i"

			cat "${server_offline_dep_files[i]}" "${online_dep_files[i]}" \
				| sort \
				| uniq \
				> "$procdir/sites/${dev}_${s_clean}/deps_server_$i"

			cat "$procdir/sites/${dev}_${s_clean}/deps_test_$i" \
				"$procdir/sites/${dev}_${s_clean}/deps_window_$i" \
				| intersection 2 \
				> "$procdir/sites/${dev}_${s_clean}/deps_overlap_$i"

			cat "$procdir/sites/${dev}_${s_clean}/deps_test_$i" \
				"$procdir/sites/${dev}_${s_clean}/deps_window_offline_$i" \
				| intersection 2 \
				> "$procdir/sites/${dev}_${s_clean}/deps_overlap_offline_$i"

			cat "$procdir/sites/${dev}_${s_clean}/deps_test_$i" \
				"$procdir/sites/${dev}_${s_clean}/deps_server_$i" \
				| intersection 2 \
				> "$procdir/sites/${dev}_${s_clean}/deps_overlap_server_$i"

			local nw_off=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_window_offline_$i")
			local no_off=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_overlap_offline_$i")
			local nw=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_window_$i")
			local no=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_overlap_$i")
			local na=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_test_$i")

			local ns=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_server_$i")
			local no_server=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_overlap_server_$i")

			python -c "print (float($nw - $no) / max($na, 1))" >> "$resdir/sites/${dev}_${s_clean}/extra"
			python -c "print (float($na - $no) / max($na, 1))" >> "$resdir/sites/${dev}_${s_clean}/missed"
			python -c "print (float($nw_off - $no_off) / max($na, 1))" >> "$resdir/sites/${dev}_${s_clean}/extra-offline"
			python -c "print (float($na - $no_off) / max($na, 1))" >> "$resdir/sites/${dev}_${s_clean}/missed-offline"
			python -c "print (float($ns - $no_server) / max($na, 1))" >> "$resdir/sites/${dev}_${s_clean}/extra-server"
			python -c "print (float($na - $no_server) / max($na, 1))" >> "$resdir/sites/${dev}_${s_clean}/missed-server"
		done
		#) &
		#dev_pids+=($!)
	done
	for p in ${dev_pids[@]}; do
		wait $p
	done
}

site_pids=()
for s in $sites; do
	(process_site "$s") &
	site_pids+=($!)
	while [[ $(jobs | wc -l) -ge 30 ]]; do
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
