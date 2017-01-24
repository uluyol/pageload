#!/usr/bin/env python3

import argparse
import base64
import collections
import json
import multiprocessing
import os
import os.path
import subprocess
import tempfile

ProcWork = collections.namedtuple(
	"ProcWork",
	["name", "inpath", "outpath", "res"])

def proc_trace(work):
	print(work.name)
	trace = {}
	with open(os.path.join(work.inpath, work.name)) as f:
		trace = json.load(f)
	mogrify = os.getenv("MOGRIFY_CMD", "mogrify").split()
	for ev in trace:
		if ev["name"] == "Screenshot":
			ev["args"]["snapshot"] = base64.b64encode(
				crop(
					base64.b64decode(ev["args"]["snapshot"]),
					work.res,
					mogrify)).decode("utf-8")
	with open(os.path.join(work.outpath, work.name), "w") as f:
		json.dump(trace, f)

def main(inpath, outpath, res):
	os.makedirs(outpath)
	with multiprocessing.Pool() as workers:
		work = (
			ProcWork(name=n, inpath=inpath, outpath=outpath, res=res)
			for n in os.listdir(inpath))
		workers.map(proc_trace, work)

def crop(input, res, mogrify):
	fd, p = tempfile.mkstemp(suffix=".jpg")
	f = os.fdopen(fd, "wb")
	f.write(input)
	f.close()
	subprocess.check_call(mogrify + ["-crop", res + "+0+0", p])
	out = ""
	with open(p, "rb") as f:
		out = f.read()
	os.remove(p)
	return out

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description="Crop big snapshots")
	parser.add_argument(
		"--in",
		dest="inpath",
		required=True,
		help="input chrome traces dir")
	parser.add_argument(
		"--out",
		dest="outpath",
		required=True,
		help="output chrome traces dir")
	parser.add_argument(
		"--res",
		dest="res",
		required=True,
		help="desired resolution (WxH)")
	args = parser.parse_args()
	main(args.inpath, args.outpath, args.res)
