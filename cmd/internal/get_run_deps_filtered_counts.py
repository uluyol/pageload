#!/usr/bin/env python

import argparse
import json
import os.path
import urlparse

import HTMLParser

import requests

class Resource(object):
	def __init__(self, url, bytes_, content_type):
		self.url = url
		self.bytes = bytes_
		self.content_type = content_type

def load_records_index(input_path):
	records_index = json.load(input_path)
	all_resources = []
	all_urls = set()
	if records_index["resources"]:
		for r in records_index["resources"]:
			all_resources.append(Resource(r["url"], r["bytes"], r["contentType"]))
			all_urls.add(r["url"])
	index_urls = set()
	for u in records_index["indexRedirectChain"]:
		index_urls.add(u)
	last_index_url = records_index["indexRedirectChain"][-1]
	online_urls = set(get_online_urls(last_index_url, records_index["indexBody"]))

	online_deps = get_online_deps(all_resources, all_urls, index_urls, online_urls)
	offline_deps, offline_urls = get_offline_deps(all_resources, all_urls, index_urls, online_urls)

	return online_deps, offline_deps, offline_urls, last_index_url

def main(records_index_input1, records_index_input2, outdir, runname, should_filter):
	online_1, offline_1, offline_urls_1, li_url_1 = load_records_index(records_index_input1)
	_, _, offline_urls_2, _ = load_records_index(records_index_input2)

	online_deps = online_1
	offline_deps, b2b_ratios = filter_b2b(online_deps, offline_1, offline_urls_1, offline_urls_2)
	last_index_url = li_url_1

	offline_deps, filtered_ratios = filter_ads(should_filter, online_deps, offline_deps, last_index_url)

	online_deps.sort(key=lambda d: d.url)
	offline_deps.sort(key=lambda d: d.url)

	with open(os.path.join(outdir, runname), "w") as f_all:
		with open(os.path.join(outdir, "priority-" + runname), "w") as f_prio:
			offline_printed = set()
			for d in offline_deps:
				if d.url in offline_printed:
					continue
				offline_printed.add(d.url)
				f_all.write(d.url + "\n")
				if is_important(d):
					f_prio.write(d.url + "\n")
	with open(os.path.join(outdir, "online-" + runname), "w") as f_all:
		with open(os.path.join(outdir, "online-priority-" + runname), "w") as f_prio:
			online_printed = set()
			for d in online_deps:
				if d.url in online_printed:
					continue
				online_printed.add(d.url)
				f_all.write(d.url + "\n")
				if is_important(d):
					f_prio.write(d.url + "\n")
	print filtered_ratios["depcounts"]["overall"]
	print filtered_ratios["depcounts"]["offline"]
	print filtered_ratios["depbytes"]["overall"]
	print filtered_ratios["depbytes"]["offline"]

	print b2b_ratios["depcounts"]["overall"]
	print b2b_ratios["depcounts"]["offline"]
	print b2b_ratios["depbytes"]["overall"]
	print b2b_ratios["depbytes"]["offline"]

def is_important(resource):
	restype = resource.content_type
	if "javascript" in restype:
		return True
	if "ecmascript" in restype:
		return True
	if "html" in restype:
		return True
	if "css" in restype:
		return True
	return False

def count_num_bytes(deps):
	return len(deps), sum(d.bytes for d in deps)

def filter_b2b(online_deps, all_offline_deps, urls_1, urls_2):
	to_keep = urls_1.intersection(urls_2)
	offline_deps = [d for d in all_offline_deps if d.url in to_keep]

	n_on, b_on = count_num_bytes(online_deps)
	n_off_all, b_off_all = count_num_bytes(all_offline_deps)
	n_off_b2b, b_off_b2b = count_num_bytes(offline_deps)

	ratios = {
		"depcounts": {
			"overall": float(n_on+n_off_b2b) / max(n_on+n_off_all, 1),
			"offline": float(n_off_b2b) / max(n_off_all, 1),
		},
		"depbytes": {
			"overall": float(b_on+b_off_b2b) / max(b_on+b_off_all, 1),
			"offline": float(b_off_b2b) / max(b_off_all, 1),
		},
	}
	return offline_deps, ratios

def filter_ads(should_filter, online_deps, offline_deps, page_url):
	if not should_filter:
		ratios = {
			"depcounts": {"overall": 0, "offline": 0},
			"depbytes": {"overall": 0, "offline": 0},
		}
		return offline_deps, ratios

	n_on, b_on = count_num_bytes(online_deps)
	n_off_all, b_off_all = count_num_bytes(offline_deps)

	offline_deps = filter_ads_by_url(offline_deps, page_url)

	n_off_noads, b_off_noads = count_num_bytes(offline_deps)

	ratios = {
		"depcounts": {
			"overall": float(n_on+n_off_noads) / max(n_on+n_off_all, 1),
			"offline": float(n_off_noads) / max(n_off_all, 1),
		},
		"depbytes": {
			"overall": float(b_on+b_off_noads) / max(b_on+b_off_all, 1),
			"offline": float(b_off_noads) / max(b_off_all, 1),
		},
	}
	return offline_deps, ratios

_FILTER_ADS_URL = "http://localhost:3000/jsonrpc"
_FILTER_ADS_HEADERS = {'content-type': 'application/json'}

def _filter_ads_by_url_send(payload):
	msg = json.dumps(payload)
	resp = requests.post(_FILTER_ADS_URL, data=msg, headers=_FILTER_ADS_HEADERS).json()
	for i in range(len(resp["result"])):
		if not resp["result"][i]:
			yield payload["params"][i]["url"]

def filter_ads_by_url(offline_deps, page_url):
	domain = urlparse.urlparse(page_url).netloc
	to_keep = set()
	payload = {
		"method": "match",
		"params": [],
		"jsonrpc": "2.0",
		"id": 0,
	}
	for dep in offline_deps:
		payload["params"].append({"url": dep.url, "domain": domain})
		if len(payload["params"]) >= 150:
			to_keep.update(_filter_ads_by_url_send(payload))
			payload["params"] = []
	to_keep.update(_filter_ads_by_url_send(payload))
	filtered = [d for d in offline_deps if d.url in to_keep]
	return filtered

def get_offline_deps(all_resources, in_all, in_index_redirects, in_online):
	to_remove = in_index_redirects.union(in_online)
	to_keep = in_all.difference(to_remove)
	return [r for r in all_resources if r.url in to_keep], to_keep

def get_online_deps(all_resources, in_all, in_index_redirects, in_online):
	to_keep = in_all.intersection(in_online)
	return [r for r in all_resources if r.url in to_keep]

def _find_attr(attrs, key):
	for a in attrs:
		if a[0] == key:
			return a[1]
	return None

class _DepExtractor(HTMLParser.HTMLParser):
	def __init__(self, dest_list, url):
		HTMLParser.HTMLParser.__init__(self)
		self._dest_list = dest_list
		self._url = url

	def handle_starttag(self, tag, attrs):
		src = _find_attr(attrs, "src")
		if tag == "link":
			rel = _find_attr(attrs, "rel")
			if rel in ["stylesheet", "preload"]:
				src = _find_attr(attrs, "href")

		if src is not None and not src.startswith("data:"):
			src = urlparse.urljoin(self._url, src)
			self._dest_list.append(src)

	def handle_startendtag(self, tag, attrs):
		self.handle_starttag(tag, attrs)
		self.handle_endtag(tag)

def get_online_urls(url, html):
	online_deps = []
	de = _DepExtractor(online_deps, url)
	de.feed(html)
	return online_deps

if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("--filter", default=False, action="store_true",
		help="filter ads/tracking")
	parser.add_argument("outdir", type=str,
		help="output directory")
	parser.add_argument("runname", type=str,
		help="run name, will be used for naming output")
	args = parser.parse_args()
	with open(os.path.join(args.outdir, "records_index.0.json")) as f1:
		with open(os.path.join(args.outdir, "records_index.1.json")) as f2:
			main(f1, f2, args.outdir, args.runname, args.filter)
