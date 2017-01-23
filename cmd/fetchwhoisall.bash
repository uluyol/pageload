#!/usr/bin/env bash

set -e

dbpath=$1
pagesdir=$2

if [[ ! -d $pagesdir || -z $dbpath ]]; then
	echo usage: fetchwhoisall.bash dbpath pagesdir >&2
	exit 12
fi

for p in "$pagesdir"/*; do
	echo "# fetching for $p"
	"${0%/*}/fetchwhois.py" --db "$dbpath" --urlf "$p"
	if [[ $? -ne 0 ]]; then
		echo failed to retrieve anything for $p >&2
	fi
done
