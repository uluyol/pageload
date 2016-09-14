#!/usr/bin/env bash

set -e

EMULATE_DEVICES=(
	iphone6
	nexus6
	nexus10
)

RECORD_TIME_MIN=30
WORKERS_PER_SHARD=20
MM_IMAGE=quay.io/uluyol/pageload-mahimahi:0.3

remove_comments_empty() {
	sed 's/#.*$//g' | sed '/^$/d'
}

strjoin() {
	local d=$1; shift
	printf "%s" "$1"; shift
	printf "${d}%s" "$@"
}

shard_lines() {
	local index=$1
	local N=$2
	local lc=0
	while read line; do
		if (( ((lc+index) % $N) == 0 )); then
			echo "$line"
		fi
		((lc = lc + 1))
	done
}

cd "${0%/*}"

page_list="$1"; shift
nodes=("$@")

if [[ -z $page_list ]]; then
	echo invalid args >&2
	exit 2
fi

for ((i=0; i < ${#nodes[@]}; i++)); do
(
	# shard by taking every nth
	node_lines=$(remove_comments_empty <../page_list/"$page_list" | shard_lines $i ${#nodes[@]})
	for ((j=0; j < WORKERS_PER_SHARD; j++)); do
		shard_lines $j $WORKERS_PER_SHARD <<<"$node_lines" | ssh "${nodes[i]}" "cat >sites_worker_$j"
		cat internal/_sharded_mahimahi_run_shard_worker.bash.in \
			| sed \
				-e "s/%%WORKER_ID%%/$j/g" \
				-e "s|%%MM_IMAGE%%|$MM_IMAGE|g" \
				-e "s|%%EMULATE_DEVICES%%|$(strjoin , "${EMULATE_DEVICES[@]}")|g" \
				-e "s|%%WIN_WS%%|$WIN_W|g" \
				-e "s|%%WIN_HS%%|$WIN_H|g" \
				-e "s/%%RECORD_TIME_MIN%%/$RECORD_TIME_MIN/g" \
			| ssh "${nodes[i]}" "cat >run_shard_worker_${j}.bash && chmod +x run_shard_worker_${j}.bash"
	done

	cat internal/_sharded_mahimahi_run_shard.bash.in \
		| sed "s/%%WORKERS_PER_SHARD%%/$WORKERS_PER_SHARD/g" \
		| ssh "${nodes[i]}" "cat >run_shard.bash && chmod +x run_shard.bash"

	ssh "${nodes[i]}" "pkill -9 -u \$(id -u ubuntu)" || true
	ssh "${nodes[i]}" "sudo docker rm -f \$(sudo docker ps -aq); tmux kill-session -t 0 &>/dev/null; tmux new-session -d \"bash \$HOME/run_shard.bash\""
) &
done

for j in $(jobs -p); do
	wait $j
done
