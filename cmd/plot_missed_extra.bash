#!/usr/bin/env bash

set -e

TOPDIR="${0%/*}"

output_pdf_prefix=$1
missed_pdf_path=${output_pdf_prefix}-missed.pdf
extra_pdf_path=${output_pdf_prefix}-extra.pdf
filtered_dep_ratio_pdf_path=${output_pdf_prefix}-filtered-dep-ratio.pdf
b2b_dep_ratio_pdf_path=${output_pdf_prefix}-b2b-dep-ratio.pdf

TMP=$(mktemp -d)
mkdir "$TMP/missed"
mkdir "$TMP/extra"
mkdir "$TMP/filtered-ratios"
mkdir "$TMP/b2b-filtered-ratios"
mkdir "$TMP/b2b-filtered-bytes-ratios"
cat results/missed_extra/sites/*/missed > "$TMP/missed/hybrid"
cat results/missed_extra/sites/*/extra > "$TMP/extra/hybrid"
cat results/missed_extra/sites/*/missed-offline > "$TMP/missed/offline"
cat results/missed_extra/sites/*/extra-offline > "$TMP/extra/offline"
cat results/missed_extra/sites/*/missed-server > "$TMP/missed/online"
cat results/missed_extra/sites/*/extra-server > "$TMP/extra/online"
cat results/missed_extra/sites/*/depcount-ratio-overall > "$TMP/filtered-ratios/count"
cat results/missed_extra/sites/*/depbytes-ratio-overall > "$TMP/filtered-ratios/bytes"
cat results/missed_extra/sites/*/b2b-depcount-ratio-overall > "$TMP/b2b-filtered-ratios/count"
cat results/missed_extra/sites/*/b2b-depbytes-ratio-overall > "$TMP/b2b-filtered-ratios/bytes"

"$TOPDIR/cdfs_missed_extra_missed.R" "$missed_pdf_path" "Fraction of Predictable Set" 0,0.25,0.5,0.75,1 "$TMP/missed"/*
"$TOPDIR/cdfs.R" "$extra_pdf_path" "Fraction of Predictable Set" 0,0.25,0.5,0.75,1 "$TMP/extra"/*
"$TOPDIR/cdfs.R" "$filtered_dep_ratio_pdf_path" "Fraction of Predictable Set" 0,0.25,0.5,0.75,1 "$TMP/filtered-ratios"/*
"$TOPDIR/cdfs.R" "$b2b_dep_ratio_pdf_path" "Fraction of Predictable Set" 0,0.25,0.5,0.75,1 "$TMP/b2b-filtered-ratios"/*
