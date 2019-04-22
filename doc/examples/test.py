#!/usr/bin/python3
import sys, os, tempfile
from subprocess import call

for file in os.listdir(sys.argv[2]):
	if not file.endswith('.tcp'): continue
	src = os.path.join(sys.argv[2], file)
	output = os.path.join(sys.argv[4], file)
	if os.path.isfile(output): os.remove(output)
	# Compiles	
	ret = call([sys.argv[1], '--compile=' + output, src])
	if ret != 0: exit(ret)
	# Run
	ret = call([sys.argv[3], '-m', 'py_compile', output])
	if ret != 0: exit(ret)
