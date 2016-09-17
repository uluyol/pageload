#!/usr/bin/env bash

set -e

TOPDIR="${0%/*}"

rm -rf processed
mkdir -p processed/cdfs

output_pdf_path=$1; shift
depcount_pdf_path=${output_pdf_path%.pdf}-filtered-depcount-ratio.pdf
depbytes_pdf_path=${output_pdf_path%.pdf}-filtered-depbytes-ratio.pdf

TMP=$(mktemp -d)
mkdir "$TMP/deps"
mkdir "$TMP/filtered-ratios"
mkdir "$TMP/filtered-bytes-ratios"
cat results/missed_extra/sites/*/missed > "$TMP/deps/missed"
cat results/missed_extra/sites/*/extra > "$TMP/deps/extra"
cat results/missed_extra/sites/*/priority-missed > "$TMP/deps/priority-missed"
cat results/missed_extra/sites/*/priority-extra > "$TMP/deps/priority-extra"
cat results/missed_extra/sites/*/depcount-ratio-overall > "$TMP/filtered-ratios/overall"
cat results/missed_extra/sites/*/depcount-ratio-offline > "$TMP/filtered-ratios/offline"
cat results/missed_extra/sites/*/depbytes-ratio-overall > "$TMP/filtered-bytes-ratios/overall"
cat results/missed_extra/sites/*/depbytes-ratio-offline > "$TMP/filtered-bytes-ratios/offline"

"$TOPDIR/cdfs.R" "$output_pdf_path" "Percentage" 0,0.25,0.5,0.75,1 "$TMP/deps"/*
"$TOPDIR/cdfs.R" "$depcount_pdf_path" "Percentage" 0,0.25,0.5,0.75,1 "$TMP/filtered-ratios"/*
"$TOPDIR/cdfs.R" "$depbytes_pdf_path" "Percentage" 0,0.25,0.5,0.75,1 "$TMP/filtered-bytes-ratios"/*
