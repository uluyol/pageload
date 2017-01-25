#!/usr/bin/env python3

import argparse
import itertools
import os.path
import subprocess

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
			ls0, ls1 = diff(p0, p1)
			if not ls0 and not ls1:
				continue
			print(p0)
			print(p1)
			fancy_print(ls0, ls1)
			input("Next?")
