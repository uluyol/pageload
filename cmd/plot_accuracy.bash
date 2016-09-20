#!/usr/bin/env bash

set -e

TOPDIR="${0%/*}"

output_pdf_prefix=$1; shift
missed_path=${output_pdf_prefix}-missed.pdf
extra_path=${output_pdf_prefix}-extra.pdf
ratios_path=${output_pdf_prefix}-frac-predictable.pdf

TMP=$(mktemp -d)
mkdir "$TMP/missed"
mkdir "$TMP/extra"
mkdir "$TMP/frac-predictable"

cat results/accuracy/sites/*/missed/hybrid > "$TMP/missed/hybrid"
cat results/accuracy/sites/*/missed/online > "$TMP/missed/online"
cat results/accuracy/sites/*/missed/offline > "$TMP/missed/offline"

cat results/accuracy/sites/*/extra/hybrid > "$TMP/extra/hybrid"
cat results/accuracy/sites/*/extra/online > "$TMP/extra/online"
cat results/accuracy/sites/*/extra/offline > "$TMP/extra/offline"

cat results/accuracy/sites/*/bytes-ratio > "$TMP/frac-predictable/bytes"
cat results/accuracy/sites/*/count-ratio > "$TMP/frac-predictable/count"

"$TOPDIR/cdfs.R" "$missed_path" "Fraction of Predictable Set" 0,0.25,0.5,0.75,1 "$TMP/missed"/*
"$TOPDIR/cdfs.R" "$extra_path" "Fraction of Predictable Set" 0,0.25,0.5,0.75,1 "$TMP/extra"/*
"$TOPDIR/cdfs.R" "$ratios_path" "Predictable / Total" 0,0.25,0.5,0.75,10 "$TMP/frac-predictable"/*
