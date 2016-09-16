#!/usr/bin/env bash

set -e

FILTER_ADS=${FILTER_ADS:-1}
WINDOW_SIZE=4
ALLOW_MISSING=1

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

sites_file=$1; shift
all_runs=("$@")
devices=($(printf "%s\n" "${all_runs[@]}" | cut -d/ -f1 | sort | uniq))

resdir=results/missed_extra

IFS=$'\n'
sites=$(remove_comments_empty <"$sites_file")
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

"$TOPDIR/cmd/filterads/runserver.bash" --tracking &
pid=$!
trap "kill -9 $pid" SIGTERM SIGQUIT EXIT SIGINT

while ! (lsof -n -iTCP:3000 | grep LISTEN) &>/dev/null; do
	sleep 1
done

mkdir -p "$procdir/sites"
mkdir -p "$resdir" || true

for s in $sites; do
	s_clean=$(clean_url "$s")
	for dev in "${devices[@]}"; do
		mkdir -p "$procdir/sites/${dev}_${s_clean}/runs"
		runs=($(printf "%s\n" "${all_runs[@]}" | grep "^$dev" | sort -g -t/ -k2 | uniq))

		dep_files=()
		priority_dep_files=()
		online_dep_files=()
		online_priority_dep_files=()
		for r in "${runs[@]}"; do
			extracted_data=$(extract_records_index "$s" "$r/$(clean_url "$s")" | clip_after_iframes)

			offline_deps=$(extracted_get_offline_dep_list.bash <<<"$extracted_data")
			online_deps=$(extracted_get_online_dep_list.bash <<<"$extracted_data")

			if [[ $FILTER_ADS -eq 1 ]]; then
				offline_deps=$(filterads.py "$s" <<<"$offline_deps")
				online_deps=$(filterads.py "$s" <<<"$online_deps")
			fi

			cut -d' ' -f1 <<<"$offline_deps" > "$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}"
			get_important <<<"$offline_deps" \
				| cut -d' ' -f1 > "$procdir/sites/${dev}_${s_clean}/runs/priority-${r//\//.}"

			cut -d' ' -f1 <<<"$online_deps" > "$procdir/sites/${dev}_${s_clean}/runs/online-${r//\//.}"
			get_important <<<"$online_deps" \
				| cut -d' ' -f1 > "$procdir/sites/${dev}_${s_clean}/runs/online-priority-${r//\//.}"

			dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}")
			priority_dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/priority-${r//\//.}")
			online_dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/online-${r//\//.}")
			online_priority_dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/online-priority-${r//\//.}")

			echo $(wc -l <"$procdir/sites/${dev}_${s_clean}/runs/online-${r//\//.}") : $(wc -l <"$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}")
		done

		mkdir -p "$resdir/sites/${dev}_${s_clean}"
		rm -f "$resdir/sites/${dev}_${s_clean}/missed"
		rm -f "$resdir/sites/${dev}_${s_clean}/extra"
		rm -f "$resdir/sites/${dev}_${s_clean}/priority-missed"
		rm -f "$resdir/sites/${dev}_${s_clean}/priority-extra"

		for ((i=WINDOW_SIZE; i < ${#dep_files[@]}; i++)); do
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

			cat "$procdir/sites/${dev}_${s_clean}/deps_test_$i" \
				"$procdir/sites/${dev}_${s_clean}/deps_window_$i" \
				| intersection 2 \
				> "$procdir/sites/${dev}_${s_clean}/deps_overlap_$i"

			nw=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_window_$i")
			no=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_overlap_$i")
			na=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_test_$i")

			(python -c "print (float($nw - $no) / max($na, 1))"; echo) >> "$resdir/sites/${dev}_${s_clean}/extra"
			(python -c "print (float($na - $no) / max($na, 1))"; echo) >> "$resdir/sites/${dev}_${s_clean}/missed"

			(
				for ((j=i-WINDOW_SIZE; j < i; j++)); do
					cat "${priority_dep_files[j]}"
				done
			) | intersection "$((WINDOW_SIZE-ALLOW_MISSING))" \
				| cat - "${online_priority_dep_files[i]}" \
				| sort \
				| uniq \
				> "$procdir/sites/${dev}_${s_clean}/priority_deps_window_$i"

			cat "${priority_dep_files[i]}" "${online_priority_dep_files[i]}" \
				| sort \
				| uniq \
				> "$procdir/sites/${dev}_${s_clean}/priority_deps_test_$i"

			cat "$procdir/sites/${dev}_${s_clean}/priority_deps_test_$i" \
				"$procdir/sites/${dev}_${s_clean}/priority_deps_window_$i" \
				| intersection 2 \
				> "$procdir/sites/${dev}_${s_clean}/priority_deps_overlap_$i"

			nw=$(wc -l <"$procdir/sites/${dev}_${s_clean}/priority_deps_window_$i")
			no=$(wc -l <"$procdir/sites/${dev}_${s_clean}/priority_deps_overlap_$i")
			na=$(wc -l <"$procdir/sites/${dev}_${s_clean}/priority_deps_test_$i")

			(python -c "print (float($nw - $no) / max($na, 1))"; echo) >> "$resdir/sites/${dev}_${s_clean}/priority-extra"
			(python -c "print (float($na - $no) / max($na, 1))"; echo) >> "$resdir/sites/${dev}_${s_clean}/priority-missed"
		done
	done
done
