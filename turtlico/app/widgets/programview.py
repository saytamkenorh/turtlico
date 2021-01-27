# Copyright (C) 2021 saytamkenorh
#
# This file is part of Turtlico.
#
# Turtlico is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Turtlico is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Turtlico.  If not, see <http://www.gnu.org/licenses/>.

from gi.repository import GObject, GLib, Gtk, Gdk, Graphene

import turtlico.compiler as compiler

from .icon import append_block_to_snapshot, ICON_WIDTH, ICON_HEIGHT


class ProgramView(Gtk.Widget, Gtk.Scrollable):
    __gtype_name__ = 'TurtlicoProgramView'

    _codebuffer: compiler.CodeBuffer
    _colors: compiler.CommandColorScheme

    _drop_target: Gtk.DropTarget
    _hadjustment: Gtk.Adjustment
    _hscroll_policy: Gtk.ScrollablePolicy
    _vadjustment: Gtk.Adjustment
    _vscroll_policy: Gtk.ScrollablePolicy

    @GObject.Property(type=Gtk.ScrollablePolicy,
                      default=Gtk.ScrollablePolicy.NATURAL)
    def vscroll_policy(self):
        return self._vscroll_policy

    @vscroll_policy.setter
    def vscroll_policy(self, value):
        self._vscroll_policy = value

    @GObject.Property(type=Gtk.ScrollablePolicy,
                      default=Gtk.ScrollablePolicy.NATURAL)
    def hscroll_policy(self):
        return self._hscroll_policy

    @GObject.Property(type=Gtk.Adjustment)
    def hadjustment(self):
        return self._hadjustment

    @GObject.Property(type=Gtk.Adjustment)
    def vadjustment(self):
        return self._vadjustment

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._codebuffer = None
        self._colors = None

        self._hadjustment = Gtk.Adjustment.new(0, 0, 0, 5, 0, 0)
        self._vadjustment = Gtk.Adjustment.new(0, 0, 0, 5, 0, 0)

        self._drop_target = Gtk.DropTarget.new(
            GLib.Bytes, Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
        self._drop_target.connect('drop', self._on_drop_target_drop)
        self._drop_target.connect('accept', self._on_drop_target_accept)
        self.add_controller(self._drop_target)

    def do_snapshot(self, snapshot: Gtk.Snapshot):
        if not self._colors:
            return
        area = Graphene.Rect().init(0, 0, self.get_width(), self.get_height())
        snapshot.append_color(
            self._colors[compiler.CommandColor.INDENTATION][0], area)
        if not self._codebuffer:
            return
        append_block_to_snapshot(self._codebuffer,
                                 snapshot, 0, 0,
                                 self, self._colors)

    def do_measure(self, orientation, for_size):
        if not self._codebuffer:
            return (0, 0, -1, -1)
        if orientation == Gtk.Orientation.HORIZONTAL:
            width = max(
                [len(line) for line in self._codebuffer.lines]) * ICON_WIDTH
            return (width, width, -1, -1)
        else:
            height = len(self._codebuffer.lines) * ICON_HEIGHT
            return (height, height, -1, -1)

    def _on_drop_target_drop(self, value: GObject.Value, x, y):
        print('kvejk')
        return True

    def _on_drop_target_accept(self, target: Gtk.DropTarget, drop: Gdk.Drop):
        #return drop.props.formats.contain_mime_type(compiler.MIME_TURTLICO_CODEPIECE)
        return True

    def do_get_request_mode(self):
        return Gtk.SizeRequestMode.CONSTANT_SIZE

    def set_colors(self, colors: compiler.CommandColorScheme):
        self._colors = colors
        self.queue_draw()


GObject.type_register(ProgramView)
