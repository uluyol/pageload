#!/usr/bin/env python3

import argparse
import json
import os.path

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

def domain_of_clean_url(u):
	return ".".join(u.split("_")[0].split(":")[0].split(".")[-2:])

def org_of(db, domain):
	org = find_org(db.get(domain, {}).get("whois", ""))
	if not org or should_ignore(org):
		return ""
	return normalize_org(org)

def main(dbpath, inpath):
	db = {}
	with open(dbpath) as f:
		db = json.load(f)
	with open(inpath) as f:
		page_domain = domain_of_clean_url(os.path.basename(inpath))
		page_org = org_of(db, page_domain)
		for line in f:
			domain = domain_of_clean_url(line.strip())
			if domain == page_domain:
				print(line.strip(), "# reason: subdomain")
			elif page_org != "" and page_org == org_of(db, domain):
				print(line.strip(), "# reason: org match")

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
