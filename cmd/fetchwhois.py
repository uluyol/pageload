#!/usr/bin/env python3

"""
Creates a database of domain -> whois information
db = {
	domain1: {
		"whois": raw whois output,
		...other fields to be preserved...
	},
	domain2: {...}
	...
}
"""

import argparse
import json
import os.path
import subprocess
import sys
import time

def main(dbpath, filepath):
	db = {}
	if os.path.exists(dbpath):
		with open(dbpath) as f:
			db = json.load(f)
	with open(filepath) as f:
		add_whois_skip_if_err(db, os.path.basename(filepath))
		for line in f:
			add_whois_skip_if_err(db, line.strip())
	with open(dbpath, "w") as f:
		json.dump(db, f)

def add_whois_skip_if_err(db, clean_url):
	try:
		add_whois(db, clean_url)
	except MaxAttemptsExceededError:
		print("exceeded try limit fetching " + clean_url, file=sys.stderr)

def add_whois(db, clean_url):
	d = domain_of_clean_url(clean_url)
	if d not in db.keys():
		db[d] = {}
	if db[d].get("whois", ""):
		# already fetched
		return
	out = getwhois(d)
	db[d]["whois"] = out

def domain_of_clean_url(u):
	return ".".join(u.split("_")[0].split(":")[0].split(".")[-2:])

class MaxAttemptsExceededError(Exception):
	def __init__(self, num_attempts):
		super().__init__()
		self.num_attemps = num_attempts

def getwhois(domain):
	MAX_TRIES = 50
	SLEEP_PERIOD = 30
	if domain.endswith(".store"):
		print("# can't get whois for " + domain)
		return ""
	print("# fetching whois for " + domain)
	for i in range(MAX_TRIES):
		try:
			output = subprocess.check_output(["whois", domain]).decode("utf-8")
			if output:
				return output
		except subprocess.CalledProcessError as e:
			if i == MAX_TRIES-1:
				raise MaxAttemptsExceededError(MAX_TRIES) from e
			time.sleep(SLEEP_PERIOD)
		except UnicodeDecodeError:
			# not much we can do here
			return ""

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description="Fetch and store WHOIS information")
	parser.add_argument(
		"--db",
		dest="db",
		required=True,
		help="json db path")
	parser.add_argument(
		"--urlf",
		dest="urlf",
		required=True,
		help="page data, clean url file with list of clean urls")
	args = parser.parse_args()
	main(args.db, args.urlf)
