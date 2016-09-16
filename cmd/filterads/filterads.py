#!/usr/bin/env python

import json
import sys

import requests

domain = sys.argv[1]

url = "http://localhost:3000/jsonrpc"
headers = {'content-type': 'application/json'}

payload = {
	"method": "match",
	"params": [],
	"jsonrpc": "2.0",
	"id": 0,
}

def do(ls):
	payload["params"] = [{"url": l.rstrip("\n"), "domain": url} for l in ls]
	msg = json.dumps(payload)
	resp = requests.post(url, data=msg, headers=headers).json()
	for i in range(len(resp["result"])):
		if not resp["result"][i]:
			sys.stdout.write(ls[i])

lines = []

for line in sys.stdin:
	lines.append(line)
	if len(lines) >= 100:
		do(lines)
		lines = []
do(lines)
