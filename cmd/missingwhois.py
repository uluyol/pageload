#!/usr/bin/env python3

import argparse
import json

_ignore_orgs = [
	"Whois Privacy Protection Service, Inc.",
	"Domains By Proxy, LLC",
	"WHOISGUARD, INC.",
	"DNStination",
	"Domain Privacy Service FBO Registrant.",
	"Contact Privacy Inc. Customer",
	"Whois Privacy",
	"whois protection",
	"RegTek Whois Envoy",
]

_ignore_orgs_norm = False

def should_ignore(org):
	global _ignore_orgs_norm
	if not _ignore_orgs_norm:
		for i in range(len(_ignore_orgs)):
			_ignore_orgs[i] = normalize_org(_ignore_orgs[i])
		_ignore_orgs_norm = True
	for o in _ignore_orgs:
		if normalize_org(org).startswith(o):
			return True
	return False

def main(dbpath):
	db = {}
	with open(dbpath) as f:
		db = json.load(f)
	for domain in db.keys():
		org = find_org(db[domain].get("whois", ""))
		if not org or should_ignore(org):
			print(domain)
		else:
			print("# %s ORG = %s" % (domain, normalize_org(org)))

_TO_TRIM = [
	".",
	"inc",
	"llc",
	"ltd",
	"td",
	"s.a",
	"l.p",
	"lp",
	"limited",
	"corporation",
	",",
]

def normalize_org(o):
	def trim_suffix(s, suffix):
		if s.endswith(suffix):
			return s[:len(s)-len(suffix)]
		return s
	o = o.lower()
	for suf in _TO_TRIM:
		o = trim_suffix(o, suf).strip()
	return o

def find_org(whois):
	for line in whois.split("\n"):
		if line.startswith("Admin Organization: "):
			slen = len("Admin Organization: ")
			return line[slen:]
	return ""

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description="Look for domains that don't have WHOIS information")
	parser.add_argument(
		"db",
		help="json db path")
	args = parser.parse_args()
	main(args.db)
