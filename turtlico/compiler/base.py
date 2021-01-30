# base.py
#
# Copyright 2020 saytamkenorh
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations
from typing import Union

import turtlico.compiler as compiler
from .utils import error


class Compilation():
    """Context of current compilation"""
    compiler: Compiler

    output: list[str]
    # Set of module ids. Module code is added at the beginning of the file
    modules_to_load: set
    # Set of global variable names. They are available in every function so
    # these names are added at start of every function.
    global_variables: set

    line: list[compiler.Command]  # Current line
    indentation: str  # Line prefix
    # Tabs are ignored after first command that is not a tab.
    # They are treated as spaces.
    increase_indent: bool

    x: int  # Index of current column
    param_level: int
    keyword_level: int
    line_start_command: compiler.Command  # First not tab command

    cmd: compiler.CommandDefinition  # Definition of current command
    cmd_data: str  # Data of current command

    def __init__(self, compiler: Compiler):
        self.output = ['#!/usr/bin/python3']
        self.modules_to_load = set()
        self.global_variables = set()
        self.compiler = compiler

        # Initializations of enabled plugins
        for p in self.compiler.project_buffer.enabled_plugins.values():
            mod = self.compiler.modules.get(p.id, None)
            if mod:
                self.modules_to_load.add(p.id)

    def compile_line(self, line, line_hint=None):
        # Line hints are used in order to get position in icons program
        # from a position in the Python code
        if line_hint:
            self.output.append(f'# Line: {line_hint}\n')
        self.line = line
        self.indentation = ''
        self.increase_indent = True

        self.x = -1
        self.y = 0
        self.param_level = 0
        self.keyword_level = 0
        self.line_start_command = None

        self.x = 0
        while self.x < len(self.line):
            out_line = len(self.output)  # noqa: F841
            cmd = self.line[self.x]
            self.cmd = cmd.definition
            self.cmd_data = cmd.data

            # Functions
            if self.cmd.command_type == compiler.CommandType.METHOD:
                self._parse_function()
                continue
            elif self.cmd.command_type == compiler.CommandType.KEYWORD:
                continue
            elif (self.cmd.command_type
                  == compiler.CommandType.KEYWORD_WITH_ARGS):
                continue
            elif self.cmd.command_type == compiler.CommandType.CODE_SNIPPET:
                continue

            # Comment (# icon) - ignores the rest of the line
            if self.cmd.id == '#' and (not self.cmd_data):
                break

            # Indentation
            if self.increase_indent:
                if self.cmd.id == 'tab':
                    self.indentation += '\t'
                    continue
                else:
                    # Found first icon that is not a tab
                    line_start_command = self.cmd.id  # noqa: F841
                    self.increase_indent = False
                    continue

            self.x += 1

    def finish(self) -> list[str]:
        modules = set()
        for mod in self.modules_to_load:
            modules.add(mod)
            modules.update(self.compiler.modules[mod].deps)
        for mod in modules:
            self.output.append(self.compiler.modules[mod].code)
        return '\n'.join(self.output)

    def _parse_function(self):
        if self.cmd.id.startswith('tcf_'):
            self.modules_to_load.add(self.cmd.function)

    def _next_icon(self, offset=1) -> Union[compiler.Command, None]:
        i = self.x + offset
        if i >= 0 and i < len(self.line):
            return self.line[i]
        return None

    def _get_no_indent(self) -> bool:
        prev_icon = self._next_icon(-1)
        p = prev_icon and prev_icon.definition.type == 3
        return self.keyword_level > 0 or self.param_level > 0 or p


class Compiler():
    project_buffer: compiler.ProjectBuffer
    write_line_hints: bool

    # Command definitions
    modules: dict[str, compiler.CommandModule]  # id - module info

    def __init__(self, project_buffer: compiler.ProjectBuffer):
        self.modules = {}
        self.write_line_hints = True

        self.project_buffer = project_buffer
        self.reload_definitions()
        self.project_buffer.connect(
            'available-commands-changed', self.reload_definitions)

    def compile(self, code: compiler.CodePiece) -> str:
        ctx = Compilation(self)

        # Actual commands
        for y in range(len(code)):
            ctx.compile_line(
                code[y],
                y if self.write_line_hints else None)

        return ctx.finish()

    def reload_definitions(self):
        self.modules.clear()

        for plugin in self.project_buffer.enabled_plugins.values():
            self.modules.update(plugin.modules)


def _print_missing_property(id: str, props: list[str]):
    error(
        'Command "{}" is missing at least one of the following required properties: {}.'.format(id, ' '.join(props))) # NOQA
