#!/usr/bin/env python3

import argparse
import itertools
import os.path
import subprocess

from urllib.parse import urlparse, parse_qs

parser = argparse.ArgumentParser()
parser.add_argument("dir")
parser.add_argument("suffix")

args = parser.parse_args()

snap_prof_site = os.listdir(args.dir)
data_name = "stable_" + args.suffix

# consider all pairs with
# snap1 == snap2
# site1 == site2
# prof1 != prof2

snaps = set()
profiles = set()
sites = set()

for sps in snap_prof_site:
	snap, ps = sps.split(".", 1)
	prof, site = ps.split("_", 1)

	snaps.add(snap)
	profiles.add(prof)
	sites.add(site)

def diff(p0, p1):
	lines0 = set()
	lines1 = set()
	with open(p0) as f:
		for line in f:
			lines0.add(line.strip())
	with open(p1) as f:
		for line in f:
			lines1.add(line.strip())
	common = lines0.intersection(lines1)
	return lines0.difference(common), lines1.difference(common)

def filter_similar_qparams(lines0, lines1):
	urls0 = []
	for l in lines0:
		url = urlparse(l)
		urls0.append(url)
	lines0_toremove = set()
	lines1_filtered = []
	similar = []
	for l in lines1:
		url = urlparse(l)
		found = False
		for i in range(len(urls0)):
			if similar_urls(url, urls0[i]):
				found = True
				similar.append("lines0 " + lines0[i])
				lines0_toremove.add(lines0[i])
				break
		if found:
			similar.append("lines1 " + l)
		else:
			lines1_filtered.append(l)
	lines0_filtered = list(set(lines0).difference(lines0_toremove))
	lines0_filtered.sort()
	num_matched = len(lines0)-len(lines0_filtered)

	return lines0_filtered, lines1_filtered, similar
			
def similar_urls(u0, u1):
	if (
		u0.scheme != u1.scheme or
		u0.netloc != u1.netloc or
		u0.path != u1.path or
		u0.params != u1.params or
		u0.fragment != u1.fragment
	):
		return False
	q0 = parse_qs(u0.query)
	q1 = parse_qs(u1.query)

	if set(q0.keys()) != set(q1.keys()):
		return False
	return True

class colors:
    BLUE = '\033[94m'
    RED = '\033[91m'
    CLEAR = '\033[0m'

def fancy_print(lineset0, lineset1):
	def pr0(s):
		print(colors.BLUE + "1  " + s + colors.CLEAR)
	def pr1(s):
		print(colors.RED + "2  " + s + colors.CLEAR)
	lines0 = list(lineset0)
	lines1 = list(lineset1)
	lines0.sort()
	lines1.sort()

	#lines0, lines1, similar = filter_similar_qparams(lines0, lines1)
	#print("%d have the same urls excluding query param values (but have same keys)" % (len(similar),))
	#for s in similar:
	#	print(":  " + s)

	i0 = 0
	i1 = 0
	while i0 < len(lines0) or i1 < len(lines1):
		if i0 >= len(lines0):
			pr1(lines1[i1])
			i1 += 1
			continue
		if i1 >= len(lines1):
			pr0(lines0[i0])
			i0 += 1
			continue
		if lines1[i1] < lines0[i0]:
			pr1(lines1[i1])
			i1 += 1
		else:
			pr0(lines0[i0])
			i0 += 1

for site in sites:
	for snap in snaps:
		for pp in itertools.combinations(profiles, 2):
			p0 = os.path.join(args.dir, "%s.%s_%s" % (snap, pp[0], site), data_name)
			p1 = os.path.join(args.dir, "%s.%s_%s" % (snap, pp[1], site), data_name)
			print("\033c", end="")
			try:
				ls0, ls1 = diff(p0, p1)
				if len(ls0) == 0 and len(ls1) == 0:
					continue
				print(p0)
				print(p1)
				fancy_print(ls0, ls1)
				input("Next?")
			except FileNotFoundError:
				continue
