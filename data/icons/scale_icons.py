#!/usr/bin/python3
import os, sys

sizes = [16, 22, 24, 32, 48, 256]
inputf = "./source.svg"

#Scalable
dir = os.path.join(sys.argv[1], "scalable")
if not os.path.isdir(dir):
	os.mkdir(dir)
os.system("cp {} {}".format(inputf, dir + "/tk.turtlico.Turtlico.svg"))

for s in sizes:
	dir = os.path.join(sys.argv[1], str(s) + "x" + str(s))
	if not os.path.isdir(dir):
		os.mkdir(dir)
	os.system("inkscape --without-gui --file={} --export-png='{}' -w {} -h {}".format(inputf, dir + "/tk.turtlico.Turtlico.png", s, s))
