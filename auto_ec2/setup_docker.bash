#!/usr/bin/env bash

set -e

nodes=("$@")

for n in "${nodes[@]}"; do
	echo setup $n...
	ssh "$n" "\
		sudo apt-get update && \
		sudo apt-get install tmux && \
		curl -fsSL https://get.docker.com/ | sudo bash"
done
