# flake8: noqa
from turtlico.compiler import Plugin, CommandCategory, LiteralParserResult
from turtlico.compiler import CommandDefinition, CommandType, CommandModule, CommandEvent, icon
from turtlico.locale import _

name='Turtle'

def tcf_get_image(data, toplevel) -> LiteralParserResult:
    return LiteralParserResult(
        'tcf_get_image({})'.format(data),
        ('tcf_get_image')
    )

def get_plugin():
    p = Plugin(name, list_priority=1)
    p.categories = [
        CommandCategory(p, '🐢', [
            CommandDefinition('go', icon('turtle/go.svg'), _('Go forward'), CommandType.METHOD, 'forward', '30'),
            CommandDefinition('left', '↺', _('Turn left'), CommandType.METHOD, 'left', '90'),
            CommandDefinition('right', '↻', _('Turn right'), CommandType.METHOD, 'right', '90'),
            CommandDefinition('seth', icon('turtle/seth.svg'), _('Set heading angle'), CommandType.METHOD, 'setheading', '0'),
            CommandDefinition('speed', icon('turtle/speed.svg'), _('Speed'), CommandType.METHOD, 'speed', '1'),
            CommandDefinition('pos', icon('turtle/pos.svg'), _('Set position'), CommandType.METHOD, 'setposition', '0,0'),
            CommandDefinition('penc', icon('turtle/penc.svg'), _('Set pen color'), CommandType.METHOD, 'color', "'black'"),
            CommandDefinition('pu', '✐', _('Lift the pen up'), CommandType.METHOD, 'penup'),
            CommandDefinition('pd', '✎', _('Put the pen down'), CommandType.METHOD, 'pendown'),
            CommandDefinition('pp', icon('turtle/pp.svg'), _('Pen properties'), CommandType.METHOD, 'pev', snippet='pp,;(,;obj,;pensize,;assign,;int,10;),;'),
            CommandDefinition('ht', icon('turtle/ht.svg'), _('Hide turtle'), CommandType.METHOD, 'hideturtle'),
            CommandDefinition('st', icon('turtle/st.svg'), _('Show turtle'), CommandType.METHOD, 'showturtle'),
            CommandDefinition('wr', icon('turtle/wr.svg'), _('Write text on screen'), CommandType.METHOD, 'write', snippet='wr,;(,;str,text;sep,;font,;sep,;obj,align;2_assign,;str,left;),;'),
            CommandDefinition('bf', icon('turtle/bf.svg'), _('Begin fill'), CommandType.METHOD, 'begin_fill'),
            CommandDefinition('ef', icon('turtle/ef.svg'), _('End fill - fill the drawn shape'), CommandType.METHOD, 'end_fill'),
            CommandDefinition('lscene', icon('turtle/last_scene.svg'), _('Last loaded scene'), CommandType.CODE_SNIPPET, 'tcf_last_scene'),
            CommandDefinition('cs', icon('turtle/cs.svg'), _('Clear turtle screen'), CommandType.METHOD, 'clear'),
            CommandDefinition('screen_c', icon('turtle/screen_c.svg'), _('Get or set the color of the screen'), CommandType.METHOD, 'bgcolor'),
            CommandDefinition('screen_i', icon('turtle/screen_i.svg'), _('Get or set the background picture of the screen'), CommandType.METHOD, 'bgpic'),
            CommandDefinition('scene', icon('turtle/scene.svg'), _('Load scene from file'), CommandType.METHOD, 'tcf_load_scene'),
            CommandDefinition('img', icon('turtle/img.svg'), _('Image file'), CommandType.LITERAL, tcf_get_image, data_only=True),
            CommandDefinition('newt', icon('turtle/newt.svg'), _('Create a new turtle'), CommandType.METHOD, 'tcf_newt'),
            CommandDefinition('gett', icon('turtle/gett.svg'), _('Get the predefined turtle object'), CommandType.METHOD, 'getturtle'),
            CommandDefinition('plcimg', icon('turtle/plcimg.svg'), _('Place image at the position of the turtle'), CommandType.METHOD, 'tcf_place_img'),
            CommandDefinition('sleep', '💤', _('Place image at the position of the turtle'), CommandType.METHOD, 'tcf_place_img'),
            CommandDefinition('tcf_collision', icon('turtle/collision.svg'), _('Circular collision'), CommandType.METHOD, 'tcf_collision'),
            CommandDefinition('tcf_collision_rect', icon('turtle/collision_rect.svg'), _('Circular collision'), CommandType.METHOD, 'tcf_collision_rect'),
            CommandDefinition('undo', '↶', _('Undo the last turtle action'), CommandType.METHOD, 'undo'),
            CommandDefinition('circle', '◯', _('Draw circle'), CommandType.METHOD, 'circle'),
            CommandDefinition('turbo', icon('turtle/turbo.svg'), _('Turbo mode'), CommandType.METHOD, 'tcf_turbo'),
            CommandDefinition('screenp', icon('turtle/screenprop.svg'), _('Camera properties'), CommandType.METHOD, 'tcf_screenprop', snippet='screenp,;(,;obj,width;assign,;int,1280;sep,;obj,height;assign,;int,720;),;'),
            CommandDefinition('ekey', '⌨', _('Connect a function to handle key presses'), CommandType.METHOD, 'tcf_keypress'),
            CommandDefinition('tmr', icon('turtle/tmr.svg'), _('Call a function after n miliseconds'), CommandType.METHOD, 'ontimer'),
            CommandDefinition('numi', '⌨#', _('Number input'), CommandType.METHOD, 'numinput', default_params="'{}','{}'".format(_('Number'), _('Enter a number:')), snippet='numi,;(,;str,{};sep,;str,{};sep,;int,50;sep,;int,100;),;'.format(_('Number'), _('Enter a number'))),
            CommandDefinition('stri', '⌨"', _('String input'), CommandType.METHOD, 'textinput', default_params="'{}','{}'".format(_('String'), _('Enter a string:')), snippet='stri,;(,;str,{};sep,;str,{};sep,;str,50;sep,;str,100;),;'.format(_('String'), _('Enter a string::'))),
            CommandDefinition('emc', icon('turtle/emc.svg'), _('Connect a function to handle mouse clicks'), CommandType.METHOD, 'tcf_mouseclick'),
            CommandDefinition('xcor()', '❓X', _('Get x coordinate'), CommandType.CODE_SNIPPET, 'xcor()'),
            CommandDefinition('ycor()', '❓Y', _('Get y coordinate'), CommandType.CODE_SNIPPET, 'ycor()'),
            CommandDefinition('visible', '❓V', _('Is turtle visible?'), CommandType.CODE_SNIPPET, 'isvisible()'),
        ])
    ]
    p.modules = {
        'turtle': CommandModule(
            deps=(),
            code="""from turtle import *
from PIL import Image
import os, time, sys
color('black');speed(1);title('Turtle');colormode(255);shape('turtle');listen()
def tcf_tk_show_error(self, exc, val, tb):
	raise
import tkinter; tkinter.Tk.report_callback_exception = tcf_tk_show_error
tcf_last_scene = None"""
        ),
        'tcf_load_scene': CommandModule(
            deps=('tcf_get_image'),
            code="""tcf_scene_turtles=[]
def tcf_load_scene(path=None):
	global tcf_last_scene; tcf_last_scene=path
	tracer_n = tracer(); tracer_delay = delay();
	import json
	if path != None:
		if not path.endswith('.tcs'):
		    project_name = os.path.basename(os.path.splitext(__file__)[0])
		    scene_name = os.path.splitext(project_name)[0]
		    path = '{}.{}.tcs'.format(scene_name, path)
		with open(path) as f:
		    scene = json.loads(f.read())
		setup(width=scene['width'], height=scene['height'], startx=None, starty=None)
		screensize(scene['width'] - 30, scene['height'] - 30)
	for t in tcf_scene_turtles:
		if t in globals(): del globals()[t]
		del t
	clearscreen(); colormode(255); tracer(0, 0)
	if 'tcf_collisions' in globals(): tcf_collisions.clear()
	if 'tcf_collisions_rect' in globals(): tcf_collisions_rect.clear()
	if path == None:
		screensize(400, 300)
	else:
		for s in scene['sprites']:
			globals()[s['id']] = Turtle(); turtle = globals()[s['id']]
			turtle.penup(); turtle.setpos(s['x'],s['y'])
			turtle.shape(tcf_get_image(s['name'])); turtle.penup()
			tcf_scene_turtles.append(s['id'])
	tracer(tracer_n, tracer_delay)"""
        ),
        'tcf_get_image': CommandModule(
            deps=(),
            code="""def tcf_get_image(path):
	if not path in getshapes():
		if not path.endswith('.gif'):
			p = Image.open(path)
			output = NamedTemporaryFile(suffix='.gif')
			p.save(output, 'GIF')
			register_shape(output.name)
			return output.name
		else:
			register_shape(path)
	return path"""
        ),
        'tcf_newt': CommandModule(
            deps=(),
            code="""def tcf_newt():
	t = Turtle()
	t.shape('turtle')
	return t"""
        ),
        'tcf_place_img': CommandModule(
            deps=(),
            code="""def tcf_place_img(image, t=None):
	turt = Turtle()
	turt.shape(image);turt.penup()
	if t != None:
		turt.setpos(t.pos())
	else:
		turt.setpos(pos())
	return turt"""
        ),
        'tcf_sleep': CommandModule(
            deps=(),
            code="""def tcf_sleep(seconds=None, block=True):
	if seconds != None and seconds < 0:
		seconds = abs(seconds); block=False
	if seconds == None:
		listen(); tcf_sleep_exit = [False, None, None]
		def set_exit(key):
			getcanvas().unbind('<Key>', tcf_sleep_exit[1])
			getcanvas().unbind('<Button-1>', tcf_sleep_exit[2]);
			tcf_sleep_exit[0]=True
		tcf_sleep_exit[1] = getcanvas().bind('<Key>', set_exit)
		tcf_sleep_exit[2] = getcanvas().bind('<Button-1>', set_exit)
		while not tcf_sleep_exit[0]:
			time.sleep(1/60); getcanvas().update()
		return
	if block: getcanvas()._root().focus_force()
	while seconds > 0:
		t=min(seconds, 1/60)
		time.sleep(t); seconds-=t; getcanvas().update()
	listen()"""
        ),
        'tcf_collision': CommandModule(
            deps=(),
            code="""tcf_collisions=[]
def tcf_collision_check():
	for c in tcf_collisions:
		if not (c[0].isvisible() and c[1].isvisible()):
			continue
		if c[0].distance(c[1].xcor(), c[1].ycor()) < c[3] + c [4]:
			if c[5] != None:
				c[2](c[5])
			else:
				c[2]()
	ontimer(tcf_collision_check, 50)
tcf_collision_check()
def tcf_collision(a, b, callback, collider_size_1=10, collider_size_2=10, user_data=None):
	tcf_collisions.append((a, b, callback, collider_size_1, collider_size_2, user_data))"""
        ),
        'tcf_collision_rect': CommandModule(
            deps=(),
            code="""tcf_collisions_rect=[]
def tcf_collision_check_rect():
	for c in tcf_collisions_rect:
		if not (c[0].isvisible() and c[1].isvisible()):
			continue
		f_top_right_x = c[0].xcor()+c[3][0]/2
		f_top_right_y = c[0].ycor()+c[3][1]/2
		f_bottom_left_x = c[0].xcor()-c[3][0]/2
		f_bottom_left_y = c[0].ycor()-c[3][1]/2
		s_top_right_x = c[1].xcor()+c[4][0]/2
		s_top_right_y = c[1].ycor()+c[4][1]/2
		s_bottom_left_x = c[1].xcor()-c[4][0]/2
		s_bottom_left_y = c[1].ycor()-c[4][1]/2
		if not (f_top_right_x < s_bottom_left_x or f_bottom_left_x > s_top_right_x or f_top_right_y < s_bottom_left_y or f_bottom_left_y > s_top_right_y):
			if c[5] != None:
				c[2](c[5])
			else:
				c[2]()
	ontimer(tcf_collision_check_rect, 50)
tcf_collision_check_rect()
def tcf_collision_rect(a, b, callback, collider_size_1=(15, 15), collider_size_2=(15, 15), user_data=None):
	tcf_collisions_rect.append((a, b, callback, collider_size_1, collider_size_2, user_data))"""
        ),
        'tcf_turbo': CommandModule(
            deps=(),
            code="""def tcf_turbo(turbo=False, do_not_render=False, t=None):
	if turbo == 3: tracer(not do_not_render); return
	if turbo == 2: trubo=True; do_not_render=True
	delay(0 if turbo else 10)
	if t == None: speed(0 if turbo else 1)
	else: t.speed(0 if turbo else 1)
	tracer(not do_not_render)"""
        ),
        'tcf_screenprop': CommandModule(
            deps=(),
            code="""def tcf_screenprop(cam_x = None, cam_y = None, width=None, height=None):
	if width != None and height != None: setup(width, height, None, None)
	if cam_x == None or cam_y == None:
		screensize(width - 30, height - 30)
		return
	global tcf_cam_x; global tcf_cam_y
	if cam_x == None: return (tcf_cam_x, tcf_cam_y)
	tcf_cam_x = int(cam_x); tcf_cam_y = int(cam_y)
	h = window_height(); w = window_width()
	screensize(max(abs(tcf_cam_x) * 2 + w, w * 2), max(abs(tcf_cam_y) * 2 + h, h * 2))
	global tcf_screenprop_first_run
	if tcf_screenprop_first_run:
		getcanvas().update(); tcf_screenprop_first_run=False
	canvas = getcanvas()
	canvas.config(xscrollincrement=1)
	canvas.config(yscrollincrement=1)
	canvas.xview_scroll(tcf_cam_x, 'units'); canvas.yview_scroll(-tcf_cam_y, 'units')
tcf_screenprop_first_run=True"""
        ),
        'tcf_keypress': CommandModule(
            deps=(),
            code="""def tcf_keypress(function=None, key=None):
	if key==None:
	    if function == None:
	    	getcanvas().unbind('<Key>'); return
	    def callback(e):
	        mods = []
	        if (e.state & 0x4) != 0: mods.append('Control_L')
	        if (e.state & 0x8) != 0: mods.append('Alt_L')
	        if (e.state & 0x80) != 0: mods.append('Alt_R')
	        if (e.state & 0x1) != 0: mods.append('Shift_L')
	        function(str(e.keysym), e.char, mods)
	    getcanvas().bind('<Key>', callback)
	else:
	    onkeypress(function, key)"""
        ),
        'tcf_mouseclick': CommandModule(
            deps=(),
            code="""def tcf_mouseclick(function=None, btn=1, turtle=None, add=None):
	if isinstance(function, Turtle): function.onclick(None); return
	if turtle==None:
	    onscreenclick(function, btn=btn, add=add)
	else:
	    turtle.onclick(function, btn=btn, add=add)"""
        ),
    }
    p.events = [
        CommandEvent(
            name=_('Key press'),
            handler='',
            connector='ekey,;(,;obj,{};),;',
            params='key,char,modifiers'
        ),
        CommandEvent(
            name=_('Specified key press'),
            handler='',
            connector='ekey,;(,;obj,{0};sep,;key,{0};),;',
            params=''
        ),
        CommandEvent(
            name=_('Mouse click'),
            handler='',
            connector='emc,;(,;obj,{};sep,;int,1;),;',
            params='x,y'
        ),
        CommandEvent(
            name=_('Mouse click on a turtle'),
            handler='',
            connector='emc,;(,;obj,{};sep,;int,1;sep,;gett,;),;',
            params='x,y'
        ),
        CommandEvent(
            name=_('Timer'),
            handler='tmr,;(,;obj,{};sep,;int,30;),;',
            connector='obj,{};(,;),;',
            params=''
        ),
        CommandEvent(
            name=_('Circular collision'),
            handler='',
            connector='collision,;(,;gett,;sep,;obj,other_turle;sep,;obj,{};sep,;int,10;sep,;int,10;),;',
            params=''
        ),
        CommandEvent(
            name=_('Rectangle collision'),
            handler='',
            connector='tcf_collision_rect,;(,;0_gett,;sep,;obj,other_turle;sep,;obj,{};sep,;(,;int,10;sep,;int,10;),;sep,;(,;int,10;sep,;int,10;),;),;',
            params=''
        ),
    ]
    return p
