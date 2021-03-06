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
from typing import Union, Tuple, Dict

import turtlico.compiler as compiler
from turtlico.locale import _


# (Python line , (Program x, Program y))
# Python line is indexed from 1
# Program x and Program y are indexed from 0
DebugInfo = Dict[int, Tuple[int, int]]

_PARAM_LEVEL_INCREASERS = ['(', '[']
_PARAM_LEVEL_DECREASERS = [')', ']']


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
    y: int  # Index of current line
    param_level: int
    keyword_level: int
    line_start_command: compiler.Command  # First not tab command
    out_line: int

    cmd: compiler.CommandDefinition  # Definition of current command
    cmd_data: str  # Data of current command

    debug_info: DebugInfo

    def __init__(self, compiler: Compiler):
        self.modules_to_load = set()
        self.global_variables = set()
        self.compiler = compiler
        self.debug_info = {}
        self.output = []
        self.x = 0
        self.y = 0
        self._append_line('')

        # Initializations of enabled plugins
        for p in self.compiler.project_buffer.enabled_plugins.values():
            mod = self.compiler.modules.get(p.id, None)
            if mod:
                self.modules_to_load.add(p.id)

    def compile_line(self, line: compiler.CodePiece, line_y: int):
        self.line = line
        self.indentation = ''
        self.increase_indent = True

        self.x = -1
        self.y = line_y
        self.param_level = 0
        self.keyword_level = 0
        self.line_start_command = None

        while self.x < len(self.line) - 1:
            self.x += 1
            out_line = len(self.output)
            cmd = self.line[self.x]
            self.cmd = cmd.definition
            self.cmd_data = cmd.data

            if self.cmd.id == 'nl':
                continue

            if self.cmd.id in _PARAM_LEVEL_INCREASERS:
                self.param_level += 1
            if self.cmd.id in _PARAM_LEVEL_DECREASERS:
                self.param_level -= 1

            if self.cmd.id == ':':
                self.output[-1] += ':'
                if self.param_level == 0 and self.keyword_level > 0:
                    self.keyword_level -= 1
                if self.param_level > 0:
                    continue
                # Support for one line conditions
                # The rest of the line is processed
                # as a part of command block
                self.indentation += '\t'
                # Makes global variables accessible from functions
                if self.line_start_command.id == 'def':
                    gv = [f'global {v};' for v in self.global_variables]
                    self._append_line(f'{self.indentation}{"".join(gv)}')
                continue

            # Indentation
            if self.increase_indent:
                if self.cmd.id == 'tab':
                    self.indentation += '\t'
                else:
                    # Found first icon that is not a tab
                    self.line_start_command = self.cmd
                    self.increase_indent = False
            elif self.cmd.id == 'tab':
                self.keyword_level = 0
                continue

            # Functions
            if self.cmd.command_type == compiler.CommandType.METHOD:
                self._parse_callable(True)
                continue
            elif self.cmd.command_type == compiler.CommandType.KEYWORD:
                self._parse_callable(False)
                continue
            elif self.cmd.command_type == compiler.CommandType.DIPERATOR:
                self._parse_callable(False, True)
                continue
            elif (self.cmd.command_type
                  == compiler.CommandType.KEYWORD_WITH_ARGS):
                if not self._get_toplevel_expression():
                    self.output[-1] += f'{self.cmd.function} '
                else:
                    self._append_line(
                        f'{self.indentation}{self.cmd.function} ')
                self.keyword_level += 1
                continue
            elif self.cmd.command_type == compiler.CommandType.CODE_SNIPPET:
                self.output[-1] += self.cmd.function
                continue
            elif self.cmd.command_type == compiler.CommandType.LITERAL:
                toplevel = self._get_toplevel_expression()
                code = self._parse_data(0, toplevel)
                if code is None:
                    code = 'None'
                if toplevel:
                    self._append_line(self.indentation + code)
                else:
                    self.output[-1] += code
                continue

            # Comment (# icon) - ignores the rest of the line
            if self.cmd.id == '#' and (not self.cmd_data):
                break

            # Repeat block of commands
            if self.cmd.id == 'rep':
                self.keyword_level += 1
                next_icon = self._next_icon()
                if next_icon is not None and next_icon.definition.id == ':':
                    self._append_line(f'{self.indentation}while True')
                    continue
                self._append_line(f'for iter_{self.x}_{out_line} in range')
                data = self._parse_data(1, False)
                if data is not None:
                    self.output[-1] += f'({data})'
                    self.x += 1  # Skips next command
                continue

            # Functions
            if self.cmd.id == 'def':
                self._parse_def()
                continue

            # Global variables
            if self.cmd.id == 'global':
                self._parse_global()
                continue

            # Direct Python code
            if self.cmd.id == 'python':
                self.output.extend(
                    [
                        f'{self.indentation}{line}'
                        for line in self.cmd_data.splitlines()
                    ]
                )

    def finish(self) -> (str, DebugInfo):
        header = []
        modules = set()
        for mod in self.modules_to_load:
            modules.add(mod)
            modules.update(self.compiler.modules[mod].deps)

        header.append('#!/usr/bin/env python')
        for mod in modules:
            for line in self.compiler.modules[mod].code.splitlines():
                header.append(line)
        header.append(f"# {_('Generated code:')}")

        # Python indexes from 1
        generated_code_offset = len(header) + 1

        debug_info_offset = {}
        for key, val in self.debug_info.items():
            debug_info_offset[key + generated_code_offset] = val

        if 'turtle' in self.compiler.modules:
            self.output.append('done()')
        self.output = header + self.output
        return '\n'.join(self.output), debug_info_offset

    def _parse_callable(self, use_parenthesis, diperator=False):
        if self.cmd.function.startswith('tcf_'):
            self.modules_to_load.add(self.cmd.function)

        if not self._get_toplevel_expression():
            self.output[-1] += self.cmd.function
            return

        next_icon = self._next_icon()
        if next_icon.definition.id in _PARAM_LEVEL_INCREASERS:
            if not diperator:
                self._append_line(self.cmd.function)
            else:
                self.output[-1] += self.cmd.function
            return

        shortdata = self._parse_data(1, False)
        params = ''
        if shortdata is not None:
            params = shortdata
            self.x += 1  # Skips next command
        elif self.cmd.default_params:
            params = self.cmd.default_params

        if use_parenthesis:
            params = f'({params})'
        else:
            if not params and diperator:
                # A parameter is required for assertions
                self.keyword_level += 1
            params = f'{params}'

        if not diperator:
            self._append_line(
                f'{self.indentation}{self.cmd.function}{params}')
        else:
            self.output[-1] += f'{self.cmd.function}{params}'

    def _parse_global(self):
        vname = self._next_icon()
        if vname is None or vname.definition.id != 'obj':
            return
        if self.indentation == '':
            self.global_variables.add(vname.data)
        assign = self._next_icon(2)
        if assign is not None and assign.definition.id == 'assign':
            # Short declaration + assignment: glob var = [something]
            self._append_line(
                f'{self.indentation}global {vname.data}; {vname.data}')
            return
        self._append_line(f'{self.indentation}global {vname.data}')

        self.x += 1  # Skips variable name

    def _parse_def(self):
        self.keyword_level += 1
        if self.line_start_command.id != 'def':
            err = _('Functions have to start on a separate line.')
            self._append_line(
                f"{self.indentation}raise SyntaxError('{err}')")
            return
        fn_name = self._next_icon(1)
        block_start = self._next_icon(2)
        if (fn_name.definition.id == 'obj'
                and block_start.definition.id == ':'):
            self._append_line(
                f'{self.indentation}def {fn_name.data}()')
            self.x += 1
            return
        self._append_line(f'{self.indentation}def ')
        return

    def _next_icon(self, offset=1) -> Union[compiler.Command, None]:
        i = self.x + offset
        if i >= 0 and i < len(self.line):
            return self.line[i]
        return None

    """Returns True if current command is not a paramater for another command
    """
    def _get_toplevel_expression(self) -> bool:
        prev_icon = self._next_icon(-1)
        is_keyword_param = (
            prev_icon
            and prev_icon.definition.command_type
            == compiler.CommandType.KEYWORD)
        return not (
            self.param_level > 0 or self.keyword_level > 0
            or is_keyword_param)

    def _parse_data(self, offset=0, toplevel=True) -> Union[str, None]:
        next_icon = self._next_icon(offset)
        if next_icon is None:
            return None
        if next_icon.data is not None:
            if (next_icon.definition.command_type
                    == compiler.CommandType.LITERAL):
                code, modules = next_icon.definition.function(
                    next_icon.data, toplevel)
                self.modules_to_load.update(modules)
                return code
            elif (next_icon.definition.command_type
                    != compiler.CommandType.INTERNAL):
                raise Exception(
                    _('Command {} can not have any data (has "{}")'
                      ).format(next_icon.definition, next_icon.data)
                )
        return None

    """Append a new line to output and creates a new entry to debug info.
    Python prints only line numbers in stack trace so it's not necessary to
    create multiple debug entries for single line.
    """
    def _append_line(self, code: str):
        self.output.append(code)
        self.debug_info[len(self.output) - 1] = (self.x, self.y)


class Compiler():
    project_buffer: compiler.ProjectBuffer

    # Command definitions
    modules: dict[str, compiler.CommandModule]  # id - module info

    def __init__(self, project_buffer: compiler.ProjectBuffer):
        self.modules = {}

        self.project_buffer = project_buffer
        self.reload_definitions()
        self.project_buffer.connect(
            'available-commands-changed', self.reload_definitions)

    def compile(self, code: compiler.CodePiece) -> (str, DebugInfo):
        ctx = Compilation(self)

        # Actual commands
        for y in range(len(code)):
            ctx.compile_line(code[y], y)

        return ctx.finish()

    def reload_definitions(self):
        self.modules.clear()

        for plugin in self.project_buffer.enabled_plugins.values():
            self.modules.update(plugin.modules)
