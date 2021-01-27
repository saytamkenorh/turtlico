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

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('GdkPixbuf', '2.0')
gi.require_version('Graphene', '1.0')
from gi.repository import Gio, Gdk, Gtk, GdkPixbuf, Graphene


class ScalableFileTexture():
    _path: str
    _cached_texture: Gdk.Texture
    _cached_texture_scale: float

    def __init__(self, path: str):
        self._path = path
        self._cached_texture = None
        self._cached_texture_scale = None

    def _reload_texture(self, scale: float):
        if scale != 1:
            res = GdkPixbuf.Pixbuf.get_file_info(self._path)
            w = res[1]
            h = res[2]
            pb: GdkPixbuf.Pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                self._path, w * scale, h * scale, True)
            self._cached_texture = Gdk.Texture.new_for_pixbuf(pb)
        else:
            file = Gio.File.new_for_path(self._path)
            self._cached_texture = Gdk.Texture.new_from_file(file)
        self._cached_texture_scale = scale

    def snapshot(self,
                 snapshot: Gtk.Snapshot,
                 bounds: Graphene.Rect, scale: float):
        if scale != self._cached_texture_scale or not self._cached_texture:
            self._reload_texture(scale)
        snapshot.append_texture(self._cached_texture, bounds)


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


def error(msg):
    _debug_message('ERROR', bcolors.FAIL, msg, sys.stderr)


def msg(msg):
    _debug_message('INFO', bcolors.OKBLUE, msg, sys.stdout)
