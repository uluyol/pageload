#!/usr/bin/env bash

if [[ $(hostname -f) =~ .*eecs.umich.edu ]]; then
	export TMPDIR=$HOME
	export MOGRIFY_CMD="junest mogrify"
fi

exec ${0%/*}/crop_big_snaps.py "$@"
