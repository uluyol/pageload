#!/usr/bin/env bash

set -e

SSH() {
	ssh \
		-o StrictHostKeyChecking=no \
		"$@"
}

destdir=$1; shift
nodes=("$@")

if [[ -e $destdir ]]; then
	echo error: $destdir already exists >&2
	exit 1
fi

mkdir -p "$destdir"

while true; do
	for n in "${nodes[@]}"; do
		if [[ $(SSH "$n" "ps ax" | grep run_shard.bash | wc -l) -lt 2 ]]; then
			echo possible error on $n, incorrect number of run_shard.bash instances
		fi
		to_move=()
		for dev in $(SSH "$n" "ls -1 shard_dl"); do
			iters=($(SSH "$n" "ls -1 shard_dl/$dev" | sort -g))
				# leave the last two for now, they may be incomplete
				for ((i=0; i < ${#iters[@]}-2; i++)); do
					to_move+=("$dev/${iters[i]}")
				done
		done
		if (( ${#to_move[@]} < 1 )); then
			echo nothing to get for $n
			continue
		fi
		printf "get $n %s\n" "${to_move[@]}"
		(cd "$destdir" && SSH "$n" "cd shard_dl && tar cz ${to_move[@]}" | tar -xzf -)
		SSH "$n" "cd shard_dl && rm -rf ${to_move[@]}"
	done
	echo sleep
	sleep 60
done
