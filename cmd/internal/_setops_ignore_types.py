#!/usr/bin/env python

import sys

setop = sys.argv[1]

show_first_only = False
show_second_only = False
show_both = False

if setop == "setdiff":
	show_first_only = True
elif setop == "union":
	show_first_only = True
	show_second_only = True
	show_both = True
elif setop == "intersection":
	show_both = True

with open(sys.argv[2]) as first:
	with open(sys.argv[3]) as second:
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
				if len(fields1) == 1:
					fields1[0] = fields1[0].rstrip("\n")
			if read2:
				line2 = second.readline()
				while line2 == "\0":
					line2 = second.readline()
				if line2 == "":
					done2 = True
				fields2 = line2.split(' ')
				if len(fields2) == 1:
					fields2[0] = fields2[0].rstrip("\n")
			if done1:
				if not done2 and show_second_only:
					for line in second:
						sys.stdout.write(line)
				break
			if done2:
				if not done1 and show_first_only:
					for line in first:
						sys.stdout.write(line)
				break
			if fields1[0] == fields2[0]:
				read1 = True
				read2 = True
				if show_both:
					sys.stdout.write(line1)
			elif fields1[0] < fields2[0]:
				read1 = True
				read2 = False
				if show_first_only:
					sys.stdout.write(line1)
			else:
				read1 = False
				read2 = True
