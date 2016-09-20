#!/usr/bin/env bash

set -e

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR/cmd/internal:$TOPDIR

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGTERM SIGQUIT EXIT SIGINT

output_pdf_path=$1; shift

datasets=("$@")

for ds in "${datasets[@]}"; do
	name=${ds##*/}
	cat "$ds"/sites/*/iou_pct > "$procdir/$name"
done

cdfs.R "$output_pdf_path" "Percent Common" 0,0.25,0.5,0.75,1 "$procdir"/*
