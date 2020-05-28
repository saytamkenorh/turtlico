#!/usr/bin/python3

import sys, os, gi
from collections import OrderedDict

gi.require_version('Json', '1.0')
from gi.repository import Json

doc_dir = os.path.dirname(os.path.realpath(__file__))
project_dir = os.path.dirname(doc_dir)
modules_dir = os.path.join(project_dir, 'src', 'plugins')

with open(os.path.join(doc_dir,'reference_doc.rst')) as f:
    doc_file = f.readlines()

i = 0
commands = {}
current_command = ""
commands[current_command] = ""

# Load already documented commands
while i < len(doc_file):
    line = doc_file[i]
    if i < (len(doc_file) - 1):
        next_line = doc_file[i+1]
    else:
        next_line = ""

    if next_line.startswith("=") and next_line[:-1] == (len(next_line)-1) * "=":
        current_command = line
        commands[current_command] = ""
        i+=2
        continue
    
    commands[current_command] += line
    i+=1

# Create new commands dict and add aleready document stuff int it
modules = os.listdir(modules_dir)
modules.sort()
new_commands = {}

for mod in modules:
    if not mod.endswith('.json'):
        continue
    with open(os.path.join(modules_dir, mod)) as f:
        mod = f.read()
    
    json = Json.from_string(mod).get_object()
    categories = json.get_array_member('categories').get_elements()
    for c in categories:
        c = c.get_object()
        cmds = c.get_array_member('commands').get_elements()
        for command in cmds:
            command = command.get_object()
            name = command.get_string_member('?') + '\n'
            if name in commands.keys():
                new_commands[name] = commands[name]
                del commands[name]
            else:
                new_commands[name] = '\n'

output_file = """=======================
Reference documentation
=======================

"""
for c in new_commands:
    output_file += c
    if len(c) > 0:
        output_file += (len(c) - 1) * "=" + "\n"
    output_file += new_commands[c]

with open(os.path.join(doc_dir,'reference_doc.rst'), 'w') as f:
    f.write(output_file)

for c in commands:
    if c == '' or c == 'Reference documentation\n':
        continue
    print("Warning: Command '{}' was not found in commmand definitions so it was removed from docs.".format(c.replace('\n', '')))