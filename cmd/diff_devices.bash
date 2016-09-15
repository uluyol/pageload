#!/usr/bin/env bash

set -e

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR

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

sites_file=$1; shift
runs=("$@")

resdir=results/"$(strjoin "~" $(printf "%s\n" "${runs[@]}" | sed 's,/,.,g' | sort))"

IFS=$'\n'
sites=$(remove_comments_empty <"$sites_file")
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

mkdir -p "$procdir/sites"
mkdir -p "$resdir" || true

for s in $sites; do
	s_clean=$(clean_url "$s")
	dep_files=()
	mkdir -p "$procdir/sites/$s_clean/runs"
	for r in "${runs[@]}"; do
		get_offline_dep_list.bash "$s" "$r" > "$procdir/sites/$s_clean/runs/${r//\//.}"
		dep_files+=("$procdir/sites/$s_clean/runs/${r//\//.}")
	done

	mkdir -p "$resdir/sites/$s_clean"
	cat "${dep_files[@]}" \
		| sort \
		| uniq -c \
		| awk "\$1 == ${#runs[@]} { print \$2 }" \
		> "$resdir/sites/$s_clean/intersection"
	cat "${dep_files[@]}" | sort | uniq > "$resdir/sites/$s_clean/union"
	ni=$(wc -l <"$resdir/sites/$s_clean/intersection")
	nu=$(wc -l <"$resdir/sites/$s_clean/union")

	(perl -e "print $ni / $nu"; echo) > "$resdir/sites/$s_clean/iou_pct"
done
