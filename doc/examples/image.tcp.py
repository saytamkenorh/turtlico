#!/usr/bin/python3
from turtle import *
from tempfile import NamedTemporaryFile
from PIL import Image
import math, random, os, time
color('black');speed(1);title('Turtle');colormode(255)
os.chdir(os.path.dirname(os.path.abspath(__file__)))
# Generated code
def tcf_get_image(path):
	if not path in getshapes():
		if not path.endswith('.gif'):
			p = Image.open(path)
			output = NamedTemporaryFile(suffix='.gif')
			p.save(output, 'GIF')
			register_shape(output.name)
			return output.name
		else:
			register_shape(path)
	return path
shape(tcf_get_image('./image.gif'))
penup()
speed(5)
t2=Turtle()
left(90)
forward(200)
right(90)
while True:
	t2.	forward(100)
	t2.	left(90)
	forward(100)
	left(90)
	left(90)
listen();done()