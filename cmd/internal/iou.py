#!/usr/bin/env python3

import sys

input_lines = []

for path in sys.argv[1:]:
	lines = set()
	with open(path) as f:
		for l in f:
			lines.add(l.strip())
	input_lines.append(lines)

if len(input_lines) == 0:
	print(0)
	sys.exit(0)

intersection = input_lines[0].copy()
union = input_lines[0].copy()

for lines in input_lines[1:]:
	intersection = intersection.intersection(lines)
	union = union.union(lines)

print(float(len(intersection)) / max(len(union), 1))
