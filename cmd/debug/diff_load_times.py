#!/usr/bin/env python3

import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument("baseline")
parser.add_argument("new")
parser.add_argument("--sortby", default="time", dest="sortby", help="values: time, diff, pct")

args = parser.parse_args()

times_baseline = {}
times_new = {}


max_key_width = 0
for path, data in [(args.baseline, times_baseline), (args.new, times_new)]:
	with open(path) as f:
		for line in f:
			fields = line.strip().split()
			max_key_width = max(max_key_width, len(fields[0]))
			data[fields[0]] = float(fields[1])

for key in set(times_baseline.keys()).difference(set(times_new.keys())):
	print("warning: skipping " + key + ": only in " + args.baseline, file=sys.stderr)

for key in set(times_new.keys()).difference(set(times_baseline.keys())):
	print("warning: skipping " + key + ": only in " + args.new, file=sys.stderr)

site_newtime_diff_pcts = []
for site, rtime in times_baseline.items():
	if site not in times_new:
		continue # already issued a warning
	diff = rtime-times_new[site]
	site_newtime_diff_pcts.append((site, times_new[site], diff, diff/rtime))

sort_key = None
if args.sortby == "time":
	sort_key = lambda t: t[1]
elif args.sortby == "diff":
	sort_key = lambda t: t[2]
elif args.sortby == "pct":
	sort_key = lambda t: t[3]
else:
	print("invalid sort key", file=sys.stderr)
	sys.exit(4)
site_newtime_diff_pcts.sort(key=sort_key)

for site, newtime, diff, pct in site_newtime_diff_pcts:
	print(site.ljust(max_key_width, " ") + "\t" + str(newtime).rjust(8, " ") + "\t" + str(diff).rjust(8, " ") + "\t" + str(int(pct * 100)).rjust(5, " ") + "%")
