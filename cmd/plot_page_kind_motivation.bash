#!/usr/bin/env bash

set -e

TOPDIR=$(realpath "${0%/*}"/..)

export PATH=$PATH:$TOPDIR/cmd/mm/bin:$TOPDIR/cmd:$TOPDIR/cmd/internal:$TOPDIR

if [[ $# -ne 1 ]]; then
	echo usage: plot_page_kind_motivation.bash output.pdf >&2
	exit 123
fi

procdir=$(mktemp -d)
trap "rm -rf $procdir" SIGINT SIGKILL SIGTERM EXIT

output_pdf_path=$1

cat results/page_kind_motivation/site_kinds/*/page-iou > "$procdir/page"
cat results/page_kind_motivation/site_kinds/*/kind-iou > "$procdir/kind"

cdfs.R "$output_pdf_path" "Intersection over Union of Dependency Sets" 0,0.25,0.5,0.75,1 "$procdir"/*
