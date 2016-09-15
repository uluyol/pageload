#!/usr/bin/env bash

set -e

TOPDIR="${0%/*}"

rm -rf processed
mkdir -p processed/cdfs

output_pdf_path=$1; shift

TMP=$(mktemp -d)
cat results/missed_extra/sites/*/missed > "$TMP/missed"
cat results/missed_extra/sites/*/extra > "$TMP/extra"
cat results/missed_extra/sites/*/priority-missed > "$TMP/priority-missed"
cat results/missed_extra/sites/*/priority-extra > "$TMP/priority-extra"
"$TOPDIR/cdfs.R" "$output_pdf_path" "Percentage" 0,0.25,0.5,0.75,1 "$TMP/"*
