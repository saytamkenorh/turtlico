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
import os
from typing import List, Tuple, Union

import gi
gi.require_version('Gdk', '4.0')
from gi.repository import GLib, GObject, Gdk, Gio

from .command import Command, IMAGE_EXTENSIONS

MIME_TURTLICO_PROJECT = 'application/x-turtlico-project'
MIME_TURTLICO_CODEPIECE = 'application/x-turtlico-codepiece'
COMMANDS_WITH_PREVIEW = ['img']

TcpPiece = List[Tuple[str, str]]
CodePiece = List[List[Command]]


class CodePieceSelection(GObject.Object):
    @GObject.Property
    def start_x(self):
        return self._start_x

    @GObject.Property
    def start_y(self):
        return self._start_y

    @GObject.Property
    def end_x(self):
        return self._end_x

    @GObject.Property
    def end_y(self):
        return self._end_y

    def __init__(self, start_x, start_y, end_x, end_y):
        super().__init__()
        self._start_x = int(start_x)
        self._start_y = int(start_y)
        self._end_x = int(end_x)
        self._end_y = int(end_y)


class UnavailableCommandException(Exception):
    pass


class CodePieceDrop(GObject.Object):
    tcppiece: TcpPiece

    def __init__(self, tcppiece: TcpPiece):
        super().__init__()
        self.tcppiece = tcppiece


class CodeBuffer(GObject.Object):
    lines: CodePiece
    project = None
    _code_data_previews: dict[str, Gdk.Texture]

    @GObject.Signal
    def code_changed(self):
        pass

    def __init__(
            self,
            project, record_history=False,
            code: str = None, ignore_errors=False):
        super().__init__()
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
        self.emit('code-changed')

    def save(self) -> TcpPiece:
        return save_tcp(self.lines)

    def insert(self, commands: CodePiece, x: int, y: int):
        clen = len(commands)
        if clen == 0:
            return

        # Validates the code to insert
        for i, line in enumerate(commands):
            if i < clen - 1 and line[-1].definition.id != 'nl':
                line.append(self.project.get_command('nl', None)[0])
            linelen = len(line)
            for li, c in enumerate(line):
                if c.definition.id == 'nl' and li < linelen - 1:
                    raise Exception('Invalid code')
                if c.definition.id not in self.project.available_commands:
                    raise UnavailableCommandException(c.definition.id)

        # Validates the coordinates
        lineslen = len(self.lines)
        if y == lineslen:
            if commands[-1][-1].definition.id != 'nl':
                self.lines.append([self.project.get_command('nl', None)[0]])
            else:
                self.lines.append([])
        elif y > lineslen or x > len(self.lines[y]):
            raise Exception('Invalid coordinates')

        # Commands that are after the inserted code on the same line
        tail = self.lines[y][x:]
        del self.lines[y][x:]
        # Inserts the code
        self.lines[y].extend(commands[0])
        self.lines[y:y] = commands[1:]

        # Adds the tail again
        if len(tail) > 0:
            y += len(commands) - 1
            if self.lines[y][-1].definition.id == 'nl':
                self.lines.insert(y + 1, tail)
            else:
                self.lines[y].extend(tail)

        self.emit('code-changed')

    def pop(self, s: CodePieceSelection) -> CodePiece:
        return self._pop(s, True)

    def delete(self, s: CodePieceSelection):
        self._pop(s, False)

    def _pop(self, s: CodePieceSelection, ret: bool = False):
        if ret:
            output = []
        update_previews = False

        for y in range(s.start_y, s.end_y + 1):
            start = 0 if y != s.start_y else s.start_x
            end = len(self.lines[y]) if y != s.end_y else s.end_x + 1
            for c in self.lines[y][start:end]:
                if (not update_previews
                        and c.definition.id in COMMANDS_WITH_PREVIEW):
                    update_previews = True
            if ret:
                output.append(self.lines[y][start:end])
            del self.lines[y][start:end]

        if update_previews:
            self._clean_code_data_previews()
        self.emit('code-changed')
        if ret:
            return output

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
        remaining_previews = self._code_data_previews.keys()
        for line in self.lines:
            for cmd in line:
                if not cmd.data:
                    continue
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
        cmd, found = project.get_command(command[0], command[1])
        if found:
            line.append(cmd)
        elif not ignore_errors:
            raise UnavailableCommandException(command[0])
        if cmd.definition.id == 'nl':
            lines.append(line)
            line = []
    if len(line) > 0:
        lines.append(line)
    return lines


def save_codepice(contents: CodePiece) -> TcpPiece:
    output = []
    for line in contents:
        for c in line:
            data = c.data.replace('\n', '\\n') if c.data else ''
            output.append((c.definition.id, data))
    return output


# TODO: Fix this in order tu support inter app transfers
def deserialize_bytes_finish(outs: Gio.MemoryOutputStream,
                             res: Gio.AsyncResult,
                             dsr: Gdk.ContentDeserializer):
    written = outs.splice_finish(res)
    if written < 0:
        dsr.return_error()
        return

    data = outs.steal_as_bytes()
    tcppiece = parse_tcp(str(data.get_data()))

    drop = CodePieceDrop(tcppiece)
    val = dsr.get_value()  # This returns None (bug?)
    val.set_pointer(drop)

    dsr.return_success()


def deserialize_bytes(dsr: Gdk.ContentDeserializer):
    ins = dsr.get_input_stream()

    flags = (Gio.OutputStreamSpliceFlags.CLOSE_SOURCE
             | Gio.OutputStreamSpliceFlags.CLOSE_TARGET)
    outs = Gio.MemoryOutputStream.new_resizable()
    outs.splice_async(
        ins,
        flags,
        dsr.get_priority(),
        dsr.get_cancellable(),
        deserialize_bytes_finish,
        dsr)


Gdk.content_register_deserializer(
    MIME_TURTLICO_CODEPIECE,
    CodePieceDrop,
    deserialize_bytes)
