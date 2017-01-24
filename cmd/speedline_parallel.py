#!/usr/bin/env python3

import multiprocessing
import os
import os.path
import subprocess
import sys

def trim_prefix(s, pre):
	if s.startswith(pre):
		return s[len(pre):]
	return s

def run(p):
	out = subprocess.check_output(["speedline", p])
	fvc = None
	vc = None
	si = None
	psi = None
	for line in out.decode("utf-8").split("\n"):
		if line.startswith("First Visual Change: "):
			fvc = int(trim_prefix(line, "First Visual Change: "))
		elif line.startswith("Visually Complete: "):
			vc = int(trim_prefix(line, "Visually Complete: "))
		elif line.startswith("Speed Index: "):
			si = float(trim_prefix(line, "Speed Index: "))
		elif line.startswith("Perceptual Speed Index: "):
			psi = float(trim_prefix(line, "Perceptual Speed Index: "))
	print("%s,%d,%d,%f,%f" % (os.path.basename(p), fvc, vc, si, psi))


with multiprocessing.Pool() as workers:
	workers.map(run, (os.path.join(sys.argv[1], p) for p in os.listdir(sys.argv[1])))
