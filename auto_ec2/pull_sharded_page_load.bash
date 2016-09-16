#!/usr/bin/env bash

set -e
set -o pipefail

SSH() {
	ssh \
		-o StrictHostKeyChecking=no \
		"$@"
}

destdir=$1; shift
nodes=("$@")

#if [[ -e $destdir ]]; then
#	echo error: $destdir already exists >&2
#	exit 1
#fi

mkdir -p "$destdir"

while true; do
	for ((node_i=0; node_i < ${#nodes[@]}; node_i++)); do
		n="${nodes[node_i]}"
		if [[ $(SSH "$n" "ps ax" | grep run_shard.bash | wc -l) -lt 2 ]]; then
			echo possible error on $n, incorrect number of run_shard.bash instances
		fi
		for dev in $(SSH "$n" "ls -1 shard_dl"); do
			iters=($(SSH "$n" "ls -1 shard_dl/$dev" | sort -g))
			# leave the last two for now, they may be incomplete
			for ((i=0; i < ${#iters[@]}-3; i++)); do
				to_move="$dev/${iters[i]}"
				echo "[$(date +'%m/%d %H:%M')] get node $node_i $to_move    ($n)"
				(cd "$destdir" && SSH "$n" "cd shard_dl && tar cz $to_move" | timeout 300 tar -xzf -)
				timeout 90 ssh -o StrictHostKeyChecking=no "$n" "cd shard_dl && rm -rf $to_move"
			done
		done
	done
	echo [$(date +'%m/%d %H:%M')] sleep
	sleep 60
done
