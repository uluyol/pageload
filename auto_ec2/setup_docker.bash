#!/usr/bin/env bash

set -e

SSH() {
	ssh \
		-o StrictHostKeyChecking=no \
		"$@"
}

nodes=("$@")

for n in "${nodes[@]}"; do
	echo setup $n...
	SSH "$n" "\
		sudo apt-get update && \
		sudo apt-get install tmux && \
		curl -fsSL https://get.docker.com/ | sudo bash"
done
