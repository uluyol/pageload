#!/usr/bin/env python3

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--from", dest="from_tstamp", default=0, type=float)
parser.add_argument("--to", dest="to_tstamp", default=float("inf"), type=float)
parser.add_argument("dep_tree")
parser.add_argument("res_send_req_trace")

args = parser.parse_args()

hinted = set()

with open(args.dep_tree) as f:
	for line in f:
		fields = line.split()
		trigger_page = fields[0]
		if trigger_page.startswith("about:blank"):
			continue
		hinted.add(fields[2])

with open(args.res_send_req_trace) as f:
	for line in f:
		fields = line.split()
		res = fields[0]
		tstamp = float(fields[2])
		if tstamp < args.from_tstamp:
			continue
		if tstamp >= args.to_tstamp:
			continue
		if res in hinted:
			print(res + " yeshint")
		else:
			print(res + " nohint")
