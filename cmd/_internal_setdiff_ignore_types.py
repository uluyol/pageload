#!/usr/bin/env python

import sys

with open(sys.argv[1]) as first:
	with open(sys.argv[2]) as second:
		read1 = True
		read2 = True
		done1 = False
		done2 = False
		line1 = None
		line2 = None
		fields1 = None
		fields2 = None
		while True:
			if read1:
				line1 = first.readline()
				while line1 == "\0":
					line1 = first.readline()
				if line1 == "":
					done1 = True
				fields1 = line1.split(' ')
			if read2:
				line2 = second.readline()
				while line2 == "\0":
					line2 = second.readline()
				if line2 == "":
					done2 = True
				fields2 = line2.split(' ')
			if done1:
				break
			if done2:
				if not done1:
					for line in first:
						sys.stdout.write(line)
				break
			if fields1[0] == fields2[0]:
				read1 = True
				read2 = True
			elif fields1[0] < fields2[0]:
				read1 = True
				read2 = False
				sys.stdout.write(line1)
			else:
				read1 = False
				read2 = True
