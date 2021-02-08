# flake8: noqa
from turtlico.compiler import Plugin, CommandCategory, CommandColor
from turtlico.compiler import CommandDefinition, CommandType, CommandModule, CommandEvent, icon
from turtlico.locale import _

name='Base'

def get_plugin():
    p = Plugin(name)
    p.categories = [
        CommandCategory(p, '⚙', [
            CommandDefinition('nl', '⏎', _('New line (enter)'), CommandType.INTERNAL, color=CommandColor.INDENTATION),
            CommandDefinition('tab', '·', _('Tab'), CommandType.INTERNAL, color=CommandColor.INDENTATION),
            CommandDefinition('#', '#', _('Comment'), CommandType.INTERNAL, color=CommandColor.COMMENT, has_data=True, data_only=True),
            CommandDefinition('sep', ',', _('Argument separator (Comma)'), CommandType.CODE_SNIPPET, ','),
            CommandDefinition('(', ',', _('Left parenthesis'), CommandType.CODE_SNIPPET, '('),
            CommandDefinition(')', ',', _('Right parenthesis'), CommandType.CODE_SNIPPET, ')'),
            CommandDefinition('if', '❔if', _('If statement'), CommandType.KEYWORD_WITH_ARGS, 'if', snippet='if,;true,;:,;nl,;tab,;'),
            CommandDefinition('else', 'else', _('Else'), CommandType.KEYWORD_WITH_ARGS, 'else'),
            CommandDefinition(':', ':', _('Begin block of commands'), CommandType.CODE_SNIPPET, ':'),
            CommandDefinition('&', 'and', _('and'), CommandType.CODE_SNIPPET, ' and '),
            CommandDefinition('||', 'or', _('or'), CommandType.CODE_SNIPPET, ' or '),
            CommandDefinition('!', 'not', _('negation'), CommandType.CODE_SNIPPET, ' not '),
            CommandDefinition('==', '==', _('equals'), CommandType.CODE_SNIPPET, '=='),
            CommandDefinition('!=', '!=', _('not equals'), CommandType.CODE_SNIPPET, '!='),
            CommandDefinition('<', '<', _('is less than'), CommandType.CODE_SNIPPET, '<'),
            CommandDefinition('>', '>', _('is greater than'), CommandType.CODE_SNIPPET, '>'),
            CommandDefinition('rep', icon('base/rep.svg'), _('Repeat block of commands'), CommandType.INTERNAL, color=CommandColor.CYCLE, snippet='rep;int,2;:;nl;tab;'),
            CommandDefinition('for', 'for', _('For loop'), CommandType.KEYWORD_WITH_ARGS, 'for', color=CommandColor.CYCLE, snippet='for;obj,n;in;range;(;int,0;sep;int,10;);:;nl;tab;'),
            CommandDefinition('in', 'in', _('is item in an list? / for items in a colletion'), CommandType.CODE_SNIPPET, 'in'),
            CommandDefinition('while', icon('base/while.svg'), _('Repeat while the condition is true'), CommandType.KEYWORD_WITH_ARGS, 'while', color=CommandColor.CYCLE, snippet='while;true;:;nl;tab;'),
            CommandDefinition('b', '🛑', _('Break out of a loop'), CommandType.KEYWORD, 'break', color=CommandColor.KEYWORD),
            CommandDefinition('c', '↦', _('Continue with the next iteration of a loop'), CommandType.KEYWORD, 'continue', color=CommandColor.KEYWORD),
            CommandDefinition('def', 'def', _('Define a function'), CommandType.INTERNAL, color=CommandColor.KEYWORD, snippet='def;obj,name;(;);:;nl;tab;'),
            CommandDefinition('r', icon('base/r.svg'), _('Return a value'), CommandType.KEYWORD_WITH_ARGS, 'return', color=CommandColor.KEYWORD),
            CommandDefinition('[', '[', _('Left square bracket'), CommandType.CODE_SNIPPET, '['),
            CommandDefinition(']', ']', _('Right square bracket'), CommandType.CODE_SNIPPET, ']'),
            CommandDefinition('len', 'len', _('Length of (string, list etc)'), CommandType.METHOD, 'len'),
            CommandDefinition('del', 'del', _('Delete an object'), CommandType.KEYWORD, 'del', color=CommandColor.KEYWORD),
            CommandDefinition('apnd', icon('base/apnd.svg'), _('Append an item to the list'), CommandType.METHOD, 'append'),
            CommandDefinition('ins', icon('base/ins.svg'), _('Insert an item to the list'), CommandType.METHOD, 'insert'),
            CommandDefinition('clr', icon('base/clr.svg'), _('Clear the list'), CommandType.METHOD, 'clear'),
            CommandDefinition('index', icon('base/index.svg'), _('Find index of the first occurence of an item in a list or string'), CommandType.METHOD, 'tcf_index'),
            CommandDefinition('slo', 'aa', _('Convert a string to lower case'), CommandType.METHOD, 'lower'),
            CommandDefinition('sup', 'AB', _('Convert a string to upper case'), CommandType.METHOD, 'upper'),
            CommandDefinition('sspl', icon('base/sspl.svg'), _('Split the string'), CommandType.METHOD, 'split', "'\\n'"),
            CommandDefinition('srep', icon('base/sspl.svg'), _('Replace a phrase with another phrase in the string'), CommandType.METHOD, 'replace'),
            CommandDefinition('global', 'Glob', _('Define global variable'), CommandType.INTERNAL, color=CommandColor.KEYWORD),
            CommandDefinition('+=', '↖', _('increase value by'), CommandType.KEYWORD, '+=', color=CommandColor.KEYWORD),
            CommandDefinition('-=', '↙', _('decrease value by'), CommandType.KEYWORD, '-=', color=CommandColor.KEYWORD),
            CommandDefinition('.', '.', _('Dot (access properties of an object)'), CommandType.KEYWORD, '.', color=CommandColor.KEYWORD),
            CommandDefinition('try', 'try:', _('Try'), CommandType.KEYWORD, 'try:', color=CommandColor.KEYWORD, snippet='try;nl;tab;nl;exc;obj,Exception;as;obj,e;:;nl;tab;'),
            CommandDefinition('exc', icon('base/exc.svg'), _('Except'), CommandType.KEYWORD_WITH_ARGS, 'except', color=CommandColor.KEYWORD),
            CommandDefinition('rs', icon('base/rs.svg'), _('Raise exception'), CommandType.KEYWORD_WITH_ARGS, 'raise', color=CommandColor.KEYWORD),
            CommandDefinition('+', '+', _('plus'), CommandType.CODE_SNIPPET, '+'),
            CommandDefinition('-', '-', _('minus'), CommandType.CODE_SNIPPET, '-'),
            CommandDefinition('*', '*', _('multiply'), CommandType.CODE_SNIPPET, '*'),
            CommandDefinition('/', '/', _('divide'), CommandType.CODE_SNIPPET, '/'),
            CommandDefinition('%', '%', _('modulo'), CommandType.CODE_SNIPPET, '%'),
            CommandDefinition('tc', '🔄', _('Type conversion'), CommandType.INTERNAL, has_data=True, data_only=False),
            CommandDefinition('python', icon('base/python.svg'), _('Direct Python code'), CommandType.INTERNAL),
            CommandDefinition('as', 'as', _('as type'), CommandType.CODE_SNIPPET, 'as', color=CommandColor.KEYWORD),
            CommandDefinition('rand', '🎲', _('Random number'), CommandType.METHOD, 'random.randint', '1,100'),
            CommandDefinition('range', icon('base/range.svg'), _('List of numbers in specified range'), CommandType.METHOD, 'range', '1,10'),
            CommandDefinition('ord', 'a→#', _('Converts a character to an int value'), CommandType.METHOD, 'ord', ''),
            CommandDefinition('chr', '#→a', _('Converts an int value to a character'), CommandType.METHOD, 'chr', ''),
            CommandDefinition('mdlist', icon('base/mdlist.svg'), _('Create multidimensional list'), CommandType.METHOD, 'tcf_mdlist', ''),
            CommandDefinition('exit', icon('base/exit.svg'), _('Exit the program'), CommandType.METHOD, 'sys.exit', '0'),
        ]),
        CommandCategory(p, '📜', [
            CommandDefinition('0', '→', _('East (0°)'), CommandType.CODE_SNIPPET, '0'),
            CommandDefinition('90', '↑', _('North (90°)'), CommandType.CODE_SNIPPET, '90'),
            CommandDefinition('180', '←', _('West (180°)'), CommandType.CODE_SNIPPET, '180'),
            CommandDefinition('270', '↓', _('South (270°)'), CommandType.CODE_SNIPPET, '270'),
            CommandDefinition('math.pi', 'π', _('Pi (3.14)'), CommandType.CODE_SNIPPET, 'math.pi'),
            CommandDefinition('sin', 'sin', _('Sine'), CommandType.METHOD, 'math.sin'),
            CommandDefinition('cos', 'cos', _('Cosine'), CommandType.METHOD, 'math.cos'),
            CommandDefinition('tan', 'tan', _('Tangent'), CommandType.METHOD, 'math.tan'),
            CommandDefinition('abs', 'abs', _('Absolute value'), CommandType.METHOD, 'abs'),
            CommandDefinition('rad', 'rad', _('Degrees to radians'), CommandType.METHOD, 'math.radians'),
            CommandDefinition('deg', 'deg', _('Radians to degrees'), CommandType.METHOD, 'math.degrees'),
            CommandDefinition('true', icon('base/true.svg'), _('True'), CommandType.CODE_SNIPPET, 'True', snippet='false;'),
            CommandDefinition('false', icon('base/false.svg'), _('False'), CommandType.CODE_SNIPPET, 'False', snippet='true;'),
            CommandDefinition('rnd', 'rnd', _('Round a number'), CommandType.METHOD, 'round'),
            CommandDefinition('floor', 'flr', _('Floor'), CommandType.METHOD, 'math.floor'),
            CommandDefinition('ceil', 'ceil', _('Ceil'), CommandType.METHOD, 'math.ceil'),
            CommandDefinition('sqrt', 'sqrt', _('Square root'), CommandType.METHOD, 'math.sqrt'),
            CommandDefinition('mmin', 'min', _('Lowest value'), CommandType.METHOD, 'min'),
            CommandDefinition('mmax', 'max', _('Highest value'), CommandType.METHOD, 'max'),
            CommandDefinition('color', '🎨', _('Color (property or editable)'), CommandType.INTERNAL, has_data=True),
            CommandDefinition('font', 'Aa', _('Font (property or editable)'), CommandType.INTERNAL, has_data=True),
            CommandDefinition('int', '🔢', _('Number'), CommandType.INTERNAL, has_data=True, data_only=True, color=CommandColor.NUMBER),
            CommandDefinition('str', '🔤', _('String'), CommandType.INTERNAL, has_data=True, data_only=True, color=CommandColor.STRING),
            CommandDefinition('obj', '🆔', _('Object'), CommandType.INTERNAL, has_data=True, data_only=True, color=CommandColor.OBJECT),
            CommandDefinition('none', icon('base/none.svg'), _('None'), CommandType.CODE_SNIPPET, 'None'),
            CommandDefinition('key', icon('base/key.svg'), _('Key'), CommandType.INTERNAL, has_data=True, data_only=False),
        ]),
        CommandCategory(p, '💾', [
            CommandDefinition('readlines', '📤', _('Read all lines from file'), CommandType.METHOD, 'tcf_readlines'),
            CommandDefinition('writelines', '📥', _('Write lines to a file'), CommandType.METHOD, 'tcf_writelines'),
            CommandDefinition('filediag', icon('base/open_file.svg'), _('File dialog'), CommandType.METHOD, 'tcf_filedialog'),
            CommandDefinition('fileis', icon('base/fileis.svg'), _('Check if file exists'), CommandType.METHOD, 'os.path.isfile'),
            CommandDefinition('diris', icon('base/diris.svg'), _('Check if directory exists'), CommandType.METHOD, 'os.path.isdir'),
            CommandDefinition('filedirdel', '␡', _('Delete file or directory'), CommandType.METHOD, 'tcf_filedirdel'),
            CommandDefinition('subfiles', icon('base/subfiles.svg'), _('Get files in directory'), CommandType.METHOD, 'tcf_subfiles'),
            CommandDefinition('subdirs', icon('base/subdirs.svg'), _('Get subdirs in directory'), CommandType.METHOD, 'tcf_subdirs'),
            CommandDefinition('dirname', icon('base/dirname.svg'), _('Get parent directory'), CommandType.METHOD, 'os.path.dirname'),
            CommandDefinition('basename', icon('base/basename.svg'), _('Get file name'), CommandType.METHOD, 'os.path.basename'),
            CommandDefinition('runc', icon('base/runc.svg'), _('Run system command'), CommandType.METHOD, 'os.system'),
            CommandDefinition('runf', icon('base/runf.svg'), _('Open file in default program'), CommandType.METHOD, 'tcf_runf'),
            CommandDefinition('time', icon('base/time.svg'), _('Get current timestamp'), CommandType.METHOD, 'time.time'),
            CommandDefinition('timestrf', icon('base/time_strf.svg'), _('Convert timestamp to string'), CommandType.METHOD, 'tcf_strftime'),
            CommandDefinition('timestrp', icon('base/time_strp.svg'), _('Convert string to timestamp'), CommandType.METHOD, 'tcf_strptime'),
        ]),
    ]
    p.modules = {
        'base': CommandModule(
            deps=[],
            code="""from tempfile import NamedTemporaryFile
import math, random, os, time, sys
from datetime import datetime
os.chdir(os.path.dirname(os.path.abspath(__file__)))"""
        ),
        'tcf_readlines': CommandModule(
            deps=[],
            code="""def tcf_readlines(file=None):
    if file == None: file = __file__ + '.save'
    f = open(file, 'r'); ret = f.readlines(); f.close()
    ret = [x.replace('\\n', '') for x in ret]
    return ret"""
        ),
        'tcf_writelines': CommandModule(
            deps=[],
            code="""def tcf_writelines(data, file=None):
    if file == None: file = __file__ + '.save'
    data = [x + '\\n' for x in data]
    f = open(file, 'w'); f.writelines(data); f.close()"""
        ),
        'tcf_filedialog': CommandModule(
            deps=[],
            code="""def tcf_filedialog(text = 'Choose a file', filter = 'All files | *', save = False):
    if sys.platform.startswith('linux'):
		from subprocess import Popen, PIPE, DEVNULL
		my_env=os.environ.copy()
		my_env['G_MESSAGES_DEBUG']=''
		if save: save = '--save'
		else: save = ''
		proc = Popen(['zenity', '--file-selection', '--title', text,
                	 '--file-filter', filter, save], stdout=PIPE, stderr=DEVNULL, stdin=DEVNULL, env=my_env)
		(output, err) = proc.communicate(); proc.wait()
		output = output.decode().replace('\\n', ''); return output
	else:
		f = filter.split(' | ')
		if len(f) == 2:
			filetypes = ((f[0], f[1]),)
		elif len(f) == 1:
			filetypes = (('Files', f[0]),)
		from tkinter import filedialog
		if save:
			path = filedialog.asksaveasfilename(title=text, filetypes=filetypes)\
			return path
		else:
			path = filedialog.askopenfile(title=text, filetypes=filetypes)
			return path.name"""
        ),
        'tcf_filedirdel': CommandModule(
            deps=[],
            code="""def tcf_filedirdel(path):
    if os.path.isfile(path):
		os.remove(path)
	elif os.path.isdir(path):
		import shutil
		shutil.rmtree(path)
	else: raise Exception('File or directory {} does not exist!'.format(path))"""
        ),
        'tcf_runf': CommandModule(
            deps=[],
            code="""def tcf_runf(file):
	import subprocess
	if sys.platform.startswith('linux'):
		from gi.repository import Gio
		result = 1
		file = Gio.File.new_for_commandline_arg(file)
		result = int(not Gio.AppInfo.launch_default_for_uri(file.get_uri(), None))
	else:
		result = subprocess.run(['start', '', file], shell=True).returncode
	if result != 0:
		raise Exception('\\nFile opening failed.')"""
        ),
        'tcf_subfiles': CommandModule(
            deps=[],
            code="""def tcf_subfiles(path):
	result = []
	for entry in os.scandir(path):
		if entry.is_file():
			result.append(entry.path)
	result.sort()
	return result"""
        ),
        'tcf_subdirs': CommandModule(
            deps=[],
            code="""def tcf_subdirs(path):
	result = []
	for entry in os.scandir(path):
		if entry.is_dir():
			result.append(entry.path)
	result.sort()
	return result"""
        ),
        'tcf_index': CommandModule(
            deps=[],
            code="""def tcf_index(list, item, start=0, direction=1):
	if direction == 0: raise Exception('Direction can not be zero.')
	if direction < 0: end = 0
	if direction > 0: end = len(list)
	for i in range(start, end, direction):
		if list[i] == item:
			return i
	return -1"""
        ),
        'tcf_mdlist': CommandModule(
            deps=[],
            code="""def tcf_mdlist(default_value, *size):
	if len(size) < 1:
		raise Exception('The list must have at least one dimension.')
	if len(size) == 1:
		return [default_value] * size[0]
	return [tcf_mdlist(default_value, *size[1:]) for i in range(size[0])]"""
        ),
        'tcf_strftime': CommandModule(
            deps=[],
            code="""def tcf_strftime(time, format='%d/%m/%y %H:%M:%S'):
	return datetime.fromtimestamp(time).strftime(format)"""
        ),
        'tcf_strptime': CommandModule(
            deps=[],
            code="""def tcf_strptime(string_time, format='%d/%m/%y %H:%M:%S'):
	return datetime.timestamp(datetime.strptime(string_time, format))"""
        ),
    }

    return p
