#!/usr/bin/env bash

set -e

dbpath=$1
pagesdir=$2
outdir=$3

if [[ ! -d $pagesdir || -z $dbpath  || -z $outdir ]]; then
	echo usage: fetchwhoisall.bash dbpath pagesdir outdir >&2
	exit 12
fi

mkdir "$outdir"

for p in "$pagesdir"/*; do
	"${0%/*}/get_fp_domains.py" --db "$dbpath" --urlf "$p" > "$outdir/${p##*/}"
done