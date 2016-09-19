#!/usr/bin/env python3
#
# unfair_intersection.py taken in a set of online and offline
# deps from extracted2onoff.py and outputs an "unfair intersection"
# where we define an unfair intersection to have the online resources
# from the first input and the intersection across all inputs of the
# offline resources hence the term unfair (since the first get special
# treatment for online).

import json
import sys

def main(oorls):
	return {
		"online": oorls[0]["online"],
		"offline": intersection(oorl["offline"] for oorl in oorls),
	}

def intersection(resource_lists):
	urls = set()
	resources = []
	for rl in resource_lists:
		for r in rl:
			if r["url"] in urls:
				continue
			resources.append(r)
			urls.add(r["url"])
	resources.sort(key=lambda r: r["url"])
	return resources

if __name__ == "__main__":
	on_off_resource_lists = json.load(sys.stdin)
	unfair_intersection = main(on_off_resource_lists)
	print(json.dumps(unfair_intersection))
