#!/usr/bin/env python3

import sys

p1 = sys.argv[1]
p2 = sys.argv[2]

lines1 = set()
lines2 = set()

with open(p1) as f1:
	for line in f1:
		lines1.add(line.strip())

with open(p2) as f2:
	for line in f2:
		lines2.add(line.strip())

intersection = lines1.intersection(lines2)
union = lines1.union(lines2)

print(float(len(intersection)) / max(len(union), 1))
