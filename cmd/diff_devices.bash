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

sites_file=$1; shift
runs=("$@")

resdir=results/"$(strjoin "~" $(printf "%s\n" "${runs[@]}" | sed 's,/,.,g' | sort))"

IFS=$'\n'
sites=$(remove_comments_empty <"$sites_file")
unset IFS

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

mkdir -p "$procdir/sites"
rm -rf "$resdir"
mkdir -p "$resdir" || true

for s in $sites; do
	s_clean=$(clean_url "$s")
	dep_files=()
	mkdir -p "$procdir/sites/$s_clean/runs"
	for r in "${runs[@]}"; do
		echo $r $s
		if [[ ! -d "$r/$(clean_url "$s")" ]] || [[ ! -f "$r/hars/$(clean_url "$s")" ]]
		then
			# skip missing directories, not much we can do here
			continue
		fi

		extract_records_index -preonload "$s" "$r" "$(clean_url "$s")" \
			| clip_after_iframes \
			| extracted_get_offline_dep_list.bash \
			| cut -d' ' -f1 \
			> "$procdir/sites/$s_clean/runs/${r//\//.}"

		dep_files+=("$procdir/sites/$s_clean/runs/${r//\//.}")
	done

	if (( ${#dep_files[@]} != ${#runs[@]} )); then
		echo skipping $s >&2
		# skip sites with no data
		continue
	fi
	mkdir -p "$resdir/sites/$s_clean"
	cat "${dep_files[@]}" \
		| sort \
		| uniq -c \
		| awk "\$1 >= ${#dep_files[@]} { print \$2 }" \
		> "$resdir/sites/$s_clean/intersection"
	cat "${dep_files[@]}" | sort | uniq > "$resdir/sites/$s_clean/union"
	ni=$(wc -l <"$resdir/sites/$s_clean/intersection")
	nu=$(wc -l <"$resdir/sites/$s_clean/union")

	if [[ $nu -eq 0 ]]; then
		echo 1 > "$resdir/sites/$s_clean/iou_pct"
	else
		python -c "print (float($ni) / $nu)" > "$resdir/sites/$s_clean/iou_pct"
	fi
done
