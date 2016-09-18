#!/usr/bin/env bash

set -e

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

if [[ $# -lt 3 ]]; then
	echo usage: pull_data_sample.bash sites_file pull_server run_path [runpath...] >&2
	exit 123
fi

sites_file=$1; shift
pull_server=$1; shift
run_paths=("$@")

IFS=$'\n'
sites=($(remove_comments_empty <$sites_file))
unset IFS

paths_in=$(mktemp)
trap "rm -f $paths_in" SIGTERM SIGINT SIGQUIT EXIT

for rp in "${run_paths[@]}"; do
	for site in "${sites[@]}"; do
		echo "$rp/$(clean_url $site)" >>"$paths_in"
	done
done

cat <<EOF | ssh "$pull_server" "cat >/tmp/pull_script.bash && chmod a+x /tmp/pull_script.bash"
#!/usr/bin/env bash

set -e

(
	while read line; do
		if [[ -e "\$line" ]]; then
			echo "\$line"
		fi
	done
) | tar -czf - -T -
EOF


ssh "$pull_server" -- "/tmp/pull_script.bash; rm -f /tmp/pull_script.bash" <"$paths_in" | tar xzvf -
