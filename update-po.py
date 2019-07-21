#!/usr/bin/python3
# Gettext does not support JSON so we need to extract messages manually
# This script mark strings quoted by ' with _()
# Then runs update-po
# And changes things back
import json, os
import subprocess

files = ['./src/base.json', './src/rpi.json', './src/mm.json']
original_data = []
src_dir = os.path.dirname(os.path.realpath(__file__))

for path in files:
	f = open(path, 'r')
	data = f.read()
	original_data.append(data)
	f.close()
	output = ""

	escaped = True
	i = 0
	while i < len(data):
		if data[i] == "'":
			escaped = not escaped
			if escaped:
				output += '")'
			else:
				output += '_("'
		else:
			output += data[i]
		i+=1
	f = open(path, 'w')
	f.write(output)
	f.close()

build_dir = os.path.join(src_dir, 'build')
os.chdir(build_dir)
subprocess.call(["ninja", "turtlico-update-po"])
os.chdir(src_dir)

for i in range(len(files)):
	f = open(files[i], 'w')
	f.write(original_data[i])
	f.close()
