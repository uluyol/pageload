#!/usr/bin/env python3

import argparse
import collections
import os.path

parser = argparse.ArgumentParser()
parser.add_argument("waterfall_dir")

args = parser.parse_args()

def rough_time(t_us):
	return int(t_us / 100000) # reduce to nearest 100 ms

def closest_before(starts, end):
	dist = [end-s for s in starts]
	min_dist = float("inf")
	min_index = 0
	for i in range(len(dist)):
		if dist[i] >= 0 and dist[i] < min_dist:
			min_dist = dist[i]
			min_index = i
	return starts[min_index]

def match_start_end(r2se):
	rse = []
	for res in r2se.keys():
		starts = r2se[res]["start"]
		ends = r2se[res]["end"]
		starts.sort()
		ends.sort()
		if len(starts) < len(ends):
			raise ValueError("expected >= number of starts and ends: got %s vs %s" % (len(starts), len(ends)))
		for i in range(len(ends)):
			if starts[i] > ends[i]:
				raise ValueError("start after end")
			rse.append((res, starts[i], ends[i]))
	return rse

res2id = {}
request_starts_ends = collections.defaultdict(lambda: collections.defaultdict(list))

with open(os.path.join(args.waterfall_dir, "ResourceSendRequest.txt")) as f:
	for line in f:
		fields = line.split()
		res2id[fields[0]] = fields[1]
		request_starts_ends[fields[0]]["start"].append(int(fields[2]))

with open(os.path.join(args.waterfall_dir, "ResourceFinish.txt")) as f:
	for line in f:
		fields = line.split()
		res2id[fields[0]] = fields[1]
		request_starts_ends[fields[0]]["end"].append(int(fields[2]))

req_start_ends = match_start_end(request_starts_ends)

#		end = int(fields[2])
#		start = closest_before(request_starts[fields[0]], end)
#		requests_start_end.append((fields[0], start, end))

req_start_ends.sort(key=lambda t: rough_time(t[1])) # sort by start

critical_path = []
i = 0
while i < len(req_start_ends):
	req, start, end = req_start_ends[i]
	critical_path.append((req, start, end))
	i += 1
	while i < len(req_start_ends) and rough_time(end) >= rough_time(req_start_ends[i][2]):
		i += 1

for req, start, end in critical_path:
	print(req, res2id[req], start, end)
