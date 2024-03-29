#!/usr/bin/env python3

import os
import os.path
import sys

from google.protobuf import text_format

import http_record_pb2 as pb

def main():
	savedir = sys.argv[1]

	saves = os.listdir(savedir)

	for s in saves:
		req_resp = pb.RequestResponse()
		with open(os.path.join(savedir, s), "rb") as f:
			encoded = f.read()
			req_resp.ParseFromString(encoded)
		print(req_resp.request.first_line.decode("utf-8"))
		print(req_resp.request.header)

if __name__ == "__main__":
	main()
