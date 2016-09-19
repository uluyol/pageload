#!/usr/bin/env python3
#
# extracted2onoff.py takes in an extracted index/resources
# json file, and outputs a set of online and offline deps
# with byte counts using the below json schema:
#
# {
#   "online": [{"url": URL, "bytes": NUM}],
#   "offline": [{"url": URL, "bytes": NUM}]
# }
#
# See unfair_intersection.py for intersection pairs (or
# groups) of online/offline dependency sets.

import argparse
import html.parser
import json
import sys
import urllib.parse

class Resource(object):
	def __init__(self, url, bytes_, content_type):
		self.url = url
		self.bytes = bytes_
		self.content_type = content_type

def main(records_index, only_important_deps):
	resources = []
	urls = set()
	if records_index["resources"]:
		for r in records_index["resources"]:
			resources.append(Resource(r["url"], r["bytes"], r["contentType"]))
			urls.add(r["url"])
	index_urls = set()
	for u in records_index["indexRedirectChain"]:
		index_urls.add(u)
	last_index_url = records_index["indexRedirectChain"][-1]
	online_urls = set(get_online_urls(last_index_url, records_index["indexBody"]))

	online_deps_gen = unique_resources(only_online_deps(resources, urls, online_urls))
	offline_deps_gen = unique_resources(only_offline_deps(resources, urls, online_urls, index_urls))

	if only_important_deps:
		online_deps_gen = only_important(online_deps_gen)
		offline_deps_gen = only_important(offline_deps_gen)

	online_deps = list(online_deps_gen)
	offline_deps = list(offline_deps_gen)

	online_deps.sort(key=lambda d: d.url)
	offline_deps.sort(key=lambda d: d.url)

	return {
		"online": [{"url": d.url, "bytes": d.bytes} for d in online_deps],
		"offline": [{"url": d.url, "bytes": d.bytes} for d in offline_deps],
	}

def only_offline_deps(resources, all_urls, online_urls, index_redirect_urls):
	to_remove = index_redirect_urls.union(online_urls)
	to_keep = all_urls.difference(to_remove)
	for r in resources:
		if r.url in to_keep:
			yield r

def only_online_deps(resources, all_urls, online_urls):
	to_keep = all_urls.intersection(online_urls)
	for r in resources:
		if r.url in to_keep:
			yield r

def only_important(deps):
	for d in deps:
		if _is_important(d):
			yield d

def _is_important(resource):
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

def unique_resources(resources):
	seen = set()
	for r in resources:
		if r.url in seen:
			continue
		seen.add(r.url)
		yield r

def _find_attr(attrs, key):
	for a in attrs:
		if a[0] == key:
			return a[1]
	return None

class _DepExtractor(html.parser.HTMLParser):
	def __init__(self, dest_list, url):
		super().__init__()
		self._dest_list = dest_list
		self._url = url

	def handle_starttag(self, tag, attrs):
		src = _find_attr(attrs, "src")
		if tag == "link":
			rel = _find_attr(attrs, "rel")
			if rel in ["stylesheet", "preload"]:
				src = _find_attr(attrs, "href")

		if src is not None and not src.startswith("data:"):
			src = urllib.parse.urljoin(self._url, src)
			self._dest_list.append(src)

	def handle_startendtag(self, tag, attrs):
		self.handle_starttag(tag, attrs)
		self.handle_endtag(tag)

def get_online_urls(url, html_text):
	online_deps = []
	de = _DepExtractor(online_deps, url)
	de.feed(html_text)
	return online_deps

if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("--only-important", default=False, dest="only_important",
		action="store_true", help="only keep important resources")
	args = parser.parse_args()
	extracted_records_index = json.load(sys.stdin)
	onoff = main(extracted_records_index, args.only_important)
	print(json.dumps(onoff))
