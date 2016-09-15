#!/usr/bin/env bash

set -e

SSH() {
	ssh \
		-o StrictHostKeyChecking=no \
		"$@"
}

SSH_HOST=$1; shift
SSH_KEY=$1; shift
NFS_MOUNT_POINT=$1; shift
nodes=("$@")

for n in "$nodes"; do
	SSH "$n" "sudo apt-get install -y -qq nfs-common portmap && sudo mkdir /mnt/vault || true"
	cat $SSH_KEY | SSH "$n" "cat >.vault.key && chmod 600 .vault.key"
	SSH "$n" "ssh -o StrictHostKeyChecking=no -i \$HOME/.vault.key -fNv -L 3049:localhost:2049 $SSH_HOST & disown"
	sleep 4
	SSH "$n" "sudo mount -t nfs -o port=3049 localhost:$NFS_MOUNT_POINT /mnt/vault"
done
