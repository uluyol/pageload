#!/usr/bin/env bash

set -e

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR

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
		| awk "\$1 == $N { print \$2 }"
}

WINDOW_SIZE=3

sites_file=$1; shift
all_runs=("$@")
devices=($(printf "%s\n" "${all_runs[@]}" | cut -d/ -f1 | sort | uniq))

resdir=results/missed_extra

IFS=$'\n'
sites=$(remove_comments_empty <"$sites_file")
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

mkdir -p "$procdir/sites"
mkdir -p "$resdir" || true

for s in $sites; do
	s_clean=$(clean_url "$s")
	for dev in "${devices[@]}"; do
		mkdir -p "$procdir/sites/${dev}_${s_clean}/runs"
		runs=($(printf "%s\n" "${all_runs[@]}" | grep "^$dev" | sort -g -t/ -k2 | uniq))

		dep_files=()
		for r in "${runs[@]}"; do
			get_offline_dep_list.bash "$s" "$r" > "$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}"
			dep_files+=("$procdir/sites/${dev}_${s_clean}/runs/${r//\//.}")
		done

		mkdir -p "$resdir/sites/${dev}_${s_clean}"
		rm -f "$resdir/sites/${dev}_${s_clean}/missed"
		rm -f "$resdir/sites/${dev}_${s_clean}/extra"

		for ((i=WINDOW_SIZE; i < ${#dep_files[@]}; i++)); do
			(
				for ((j=i-WINDOW_SIZE; j < i; j++)); do
					cat "${dep_files[j]}"
				done
			) | intersection "$WINDOW_SIZE" > "$procdir/sites/${dev}_${s_clean}/deps_window_$i"

			cat "${dep_files[i]}" "$procdir/sites/${dev}_${s_clean}/deps_window_$i" \
				| intersection 2 \
				> "$procdir/sites/${dev}_${s_clean}/deps_overlap_$i"

			nw=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_window_$i")
			no=$(wc -l <"$procdir/sites/${dev}_${s_clean}/deps_overlap_$i")
			na=$(wc -l <"${dep_files[i]}")

			(perl -e "print (($nw - $no) / $na)"; echo) >> "$resdir/sites/${dev}_${s_clean}/extra"
			(perl -e "print (($na - $no) / $na)"; echo) >> "$resdir/sites/${dev}_${s_clean}/missed"
		done
	done
done
