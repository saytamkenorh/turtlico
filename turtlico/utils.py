# utils.py
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

import os
import sys
import inspect
from datetime import datetime
from typing import Callable

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Rsvg', '2.0')
gi.require_version('Graphene', '1.0')
from gi.repository import GLib, Gdk, Gtk, Rsvg, Graphene


class SVGFileTexture():
    _path: str
    _handle: Rsvg.Handle

    def __init__(self, path: str):
        self._path = path
        self._handle = Rsvg.Handle.new_from_file(path)

    def snapshot(self,
                 snapshot: Gtk.Snapshot,
                 bounds: Graphene.Rect):

        cr = snapshot.append_cairo(bounds)
        rect = Rsvg.Rectangle()
        rect.x = bounds.get_x()
        rect.y = bounds.get_y()
        rect.width = bounds.get_width()
        rect.height = bounds.get_height()
        self._handle.render_document(cr, rect)


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def rgba(string):
    c = Gdk.RGBA()
    c.parse(string)
    return c


def _get_time() -> str:
    now = datetime.now()
    return now.strftime('%H:%M:%S')


def _debug_message(mtype, color, msg, output):
    s = inspect.stack()[2]
    filename = os.path.basename(s.filename)
    print(
        f'[Turtlico] {color}{bcolors.BOLD}{mtype}{bcolors.ENDC} {filename}:{s.function}:{s.lineno} ({_get_time()}): {msg}',  # NOQA
        file=output)


def debug(msg):
    _debug_message('DEBUG', bcolors.OKGREEN, msg, sys.stdout)


def error(msg):
    _debug_message('ERROR', bcolors.FAIL, msg, sys.stderr)


def msg(msg):
    _debug_message('INFO', bcolors.OKBLUE, msg, sys.stdout)


def new_shortcut(trigger: str,
                 callback: Callable[[Gtk.Widget, GLib.Variant], bool]
                 ) -> Gtk.Shortcut:
    _trigger = Gtk.ShortcutTrigger.parse_string(trigger)
    _action = Gtk.CallbackAction.new(callback)
    shortcut = Gtk.Shortcut.new(_trigger, _action)
    return shortcut
