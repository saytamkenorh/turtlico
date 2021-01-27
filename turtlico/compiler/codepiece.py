# codepiece.py
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
from typing import List, Tuple, Union
import os

import gi
gi.require_version('Gdk', '4.0')
from gi.repository import GLib, GObject, Gdk, Gio

from .command import Command, IMAGE_EXTENSIONS

MIME_TURTLICO_PROJECT = 'application/x-turtlico-project'
MIME_TURTLICO_CODEPIECE = 'application/x-turtlico-codepiece'

TcpPiece = List[Tuple[str, str]]
CodePiece = List[List[Command]]


class UnavailableCommandException(Exception):
    pass


class CodeBuffer(GObject.Object):
    lines: CodePiece
    project = None
    _code_data_previews: dict[str, Gdk.Texture]

    @GObject.Signal
    def code_changed(self):
        self._clean_code_data_previews()

    def __init__(
            self,
            project, record_history=False,
            code: str = None, ignore_errors=False):
        self.project = project
        self._code_data_previews = {}
        if code is not None:
            self.load(parse_tcp(code), ignore_errors)
        else:
            self.load(None, False)

    def load(self, code: TcpPiece, ignore_errors=False):
        self._code_data_previews.clear()
        if code is None:
            self.lines = []
            return
        self.lines = load_codepiece(code, self.project)

    def save(self) -> TcpPiece:
        return save_tcp(self.lines)

    def get_command_data_preview(self,
                                 command: Command
                                 ) -> Union[Gdk.Texture, None]:
        if id == 'img':
            if command.data not in self._code_data_previews:
                self._generate_command_data_preview(command)
            return self._code_data_previews[command.data]
        return None

    def _generate_command_data_preview(self, command: Command):
        key = command.definition.id + command.data
        ext = os.path.splitext(command.data)[0]
        if ext not in IMAGE_EXTENSIONS:
            self._code_data_previews[key] = None
            return
        if not os.path.isfile(key):
            self._code_data_previews[key] = None
            return

        file = Gio.File.new_for_path(key)
        try:
            texture = Gdk.Texture.new_from_file(file)
        except GLib.Error:
            texture = None
        self._code_data_previews[key] = texture

    def _clean_code_data_previews(self):
        remaining_previews = self._code_data_previews.keys().copy()
        for line in self.lines:
            for cmd in line:
                key = cmd.definition.id + cmd.data
                remaining_previews.pop(key, None)
        for key in remaining_previews:
            del self._code_data_previews[key]


def parse_tcp(contents: str) -> TcpPiece:
    output = []  # Contains tuples (,)

    cmd = []
    field = []
    ignore_drivers = False
    for c in contents:
        if not ignore_drivers:
            if c == '\\':
                ignore_drivers = True
                continue
            elif c == ',':
                cmd.append(''.join(field))
                field = []
                continue
            elif c == ';':
                if len(field) > 0:
                    cmd.append(''.join(field))
                if len(cmd) < 2:
                    cmd.append('')
                output.append(tuple(cmd))
                field = []
                cmd.clear()
                continue
        ignore_drivers = False
        field.append(c)
    return output


def save_tcp(contents: TcpPiece) -> str:
    output = []
    for c in contents:
        data = (c[1].
                replace('\\', '\\\\').replace(',', '\\,').replace(';', '\\;'))
        output.append(f'{c[0]},{data};')
        if c[0] == 'nl':
            output.append('\n')
    return ''.join(output)


def load_codepiece(contents: TcpPiece,
                   project, ignore_errors=False) -> CodePiece:
    lines = []
    line = []
    for command in contents:
        if command[0] == 'nl':
            lines.append(line)
            line = []
        cmd, found = project.get_command(command[0], command[1])
        if found:
            line.append(cmd)
        elif not ignore_errors:
            raise UnavailableCommandException(command[0])
    return lines


def save_codepice(contents: CodePiece):
    output = []
    for line in contents:
        for c in line:
            data = c.data.replace('\n', '\\n') if c.data else ''
            output.append((c.definition.id, data))
    return output
