#!/usr/bin/env python
#
# Given an input html file, pull out urls from source
# attributes and link rel=[stylesheet, preload] href
# attributes.

import HTMLParser
import sys
import urlparse

def find_attr(attrs, key):
	for a in attrs:
		if a[0] == key:
			return a[1]
	return None

class DepExtractor(HTMLParser.HTMLParser):
	def __init__(self, destf, url):
		HTMLParser.HTMLParser.__init__(self)
		self._destf = destf
		self._url = url

	def handle_starttag(self, tag, attrs):
		src = find_attr(attrs, "src")
		if tag == "link":
			rel = find_attr(attrs, "rel")
			if rel in ["stylesheet", "preload"]:
				src = find_attr(attrs, "href")

		if src is not None and not src.startswith("data:"):
			src = urlparse.urljoin(self._url, src)
			self._destf.write("%s\n" % (src,))

	def handle_startendtag(self, tag, attrs):
		self.handle_starttag(tag, attrs)
		self.handle_endtag(tag)

if __name__ == "__main__":
	url = sys.argv[1]
	extractor = DepExtractor(sys.stdout, url)
	for line in sys.stdin:
		extractor.feed(line)
