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

from __future__ import annotations
import math

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Graphene', '1.0')
from gi.repository import GObject, Gtk, Gdk, Graphene, Pango

import turtlico.compiler as compiler
import turtlico.utils as utils

ICON_WIDTH = 50
ICON_HEIGHT = 35

_FONT_NORMAL: Pango.FontDescription = Pango.FontDescription.new()
_FONT_NORMAL.set_weight(Pango.Weight.BOLD)
_FONT_NORMAL.set_size(15 * Pango.SCALE)

_FONT_SMALL: Pango.FontDescription = Pango.FontDescription.new()
_FONT_SMALL.set_family('Monospace')
_FONT_SMALL.set_weight(Pango.Weight.THIN)
_FONT_SMALL.set_size(9 * Pango.SCALE)


class SingleIconWidget(Gtk.Widget):
    __gtype_name__ = 'SingleIconWidget'

    _colors: compiler.CommandColorScheme
    _command: compiler.Command
    _drag_source: Gtk.DragSource

    def __init__(self, colors: compiler.CommandColorScheme):
        super().__init__()
        self._colors = colors
        self._command = None

        self.props.has_tooltip = True

        self._drag_source = Gtk.DragSource.new()
        self._drag_source.set_actions(Gdk.DragAction.COPY)
        self._drag_source.connect('prepare', self._on_drag_prepare)
        self.add_controller(self._drag_source)

    def do_snapshot(self, snapshot):
        if not self._command:
            return
        append_to_snapshot(self._command,
                           snapshot, 0, 0,
                           self, self._colors)

    def do_measure(self, orientation, for_size):
        if orientation == Gtk.Orientation.HORIZONTAL:
            return (ICON_WIDTH, ICON_WIDTH, -1, -1)
        else:
            return (ICON_HEIGHT, ICON_HEIGHT, -1, -1)

    def do_get_request_mode(self):
        return Gtk.SizeRequestMode.CONSTANT_SIZE

    def do_query_tooltip(self,
                         x, y,
                         keyboard_tooltip: bool,
                         tooltip: Gtk.Tooltip) -> bool:
        if self._command is None:
            return False
        tooltip.set_text(self._command.definition.help)
        return True

    def set_command(self, command: compiler.Command):
        self._command = command
        self.queue_draw()

    def _on_drag_prepare(self,
                         source: Gtk.DragSource, x: float, y: float
                         ) -> Gdk.ContentProvider:
        commands = [[self._command]]

        return prepare_drag(source, commands, self, self._colors)


def append_block_to_snapshot(commands: compiler.CodePiece,
                             snapshot: Gtk.Snapshot, tx: int, ty: int,
                             widget: Gtk.Widget,
                             colors: compiler.CommandColorScheme,
                             code: compiler.CodeBuffer = None,
                             start_x=0, end_x=None,
                             start_y=0, end_y=None) -> (int, int):
    width = 0
    height = 0
    for y, line in enumerate(commands):
        if y < start_y:
            continue
        if end_y and y >= end_y:
            break
        height += 1
        render_x = 0
        for x, command in enumerate(line):
            if x < start_x:
                continue
            if end_x and x >= end_x:
                break
            if render_x > width:
                width = render_x
            xp = tx + render_x * ICON_WIDTH
            yp = ty + y * ICON_HEIGHT
            render_x += append_to_snapshot(
                command, snapshot, xp, yp, widget, colors, code)
    width += 1  # X is indexed from 0
    return (width * ICON_WIDTH, height * ICON_HEIGHT)


def append_to_snapshot(cmd: compiler.Command,
                       snapshot: Gtk.Snapshot, x, y,
                       widget: Gtk.Widget, colors: compiler.CommandColorScheme,
                       code: compiler.CodeBuffer = None) -> int:
    defin: compiler.CommandDefinition = cmd.definition
    bg, fg = colors[defin.color]
    # Extend the width of the icon for icons with data
    data_layout, icon_width = _create_data_layout(cmd, widget)

    area = Graphene.Rect.init(
        Graphene.Rect(), x, y, icon_width * ICON_WIDTH, ICON_HEIGHT)

    # Background
    snapshot.append_color(bg, area)
    # Foreground icon
    if not (defin.data_only and cmd.data):
        if isinstance(defin.icon, str):
            layout = widget.create_pango_layout(defin.icon)
            _append_layout(snapshot, layout, _FONT_NORMAL, fg, area)
        else:
            defin.icon.snapshot(snapshot, area)
    # Data
    if cmd.data and cmd.definition.show_data:
        if defin.id == 'img' and code:
            texture = code.get_command_data_preview(cmd)
            if texture:
                snapshot.append_texture(texture, area)
        if defin.id == 'color':
            data_color = utils.rgba(f'rgb({cmd.data})')
            layout = widget.create_pango_layout('⬤')
            _append_layout(snapshot, layout, _FONT_NORMAL, data_color, area)
        if data_layout:
            _append_layout(
                snapshot, data_layout, None, fg, area,
                0 if defin.data_only else 5)
    return icon_width


def calc_icon_width(cmd: compiler.Command,
                    widget: Gtk.Widget) -> int:
    return _create_data_layout(cmd, widget)[1]


def _create_data_layout(cmd: compiler.Command,
                        widget: Gtk.Widget) -> (Pango.Layout, int):
    icon_width = 1
    layout = None
    if cmd.data and cmd.definition.show_data:
        layout = widget.create_pango_layout(cmd.data)
        layout.set_font_description(_FONT_SMALL)
        data_layout_width = layout.get_pixel_size()[0]
        icon_width = max(icon_width, math.ceil(data_layout_width / ICON_WIDTH))
    return (layout, icon_width)


def _append_layout(snapshot: Gtk.Snapshot,
                   layout: Pango.Layout, font, color: Gdk.RGBA,
                   area: Graphene.Rect, y=0):
    if font:
        layout.set_font_description(font)
    layout.set_alignment(Pango.Alignment.CENTER)
    layout.set_width(area.size.width * Pango.SCALE)
    x = area.get_x()
    y = (area.get_y() + y
         + area.size.height / 2 - layout.get_pixel_size()[1] / 2)

    translate_required = x != 0 or y != 0
    if translate_required:
        snapshot.save()
        snapshot.translate(Graphene.Point.init(Graphene.Point(), x, y))
    snapshot.append_layout(layout, color)
    if translate_required:
        snapshot.restore()


def get_default_colors() -> compiler.CommandColorScheme:
    _white = utils.rgba('rgb(255, 255, 255)')
    _black = utils.rgba('rgb(0, 0, 0)')
    _default_bg = utils.rgba('rgb(255, 179, 0)')
    colors = {
        compiler.CommandColor.DEFAULT: (_default_bg, _white),
        compiler.CommandColor.INDENTATION: (_black, _white),
        compiler.CommandColor.COMMENT: (utils.rgba('rgb(255, 233, 140)'),
                                        _black),
        compiler.CommandColor.CYCLE: (utils.rgba('rgb(200, 0, 0)'), _white),
        compiler.CommandColor.KEYWORD: (_default_bg,
                                        utils.rgba('rgb(0, 0, 128)')),
        compiler.CommandColor.NUMBER: (utils.rgba('rgb(0, 0, 128)'),
                                       _white),
        compiler.CommandColor.STRING: (utils.rgba('rgb(255, 220, 0)'),
                                       _black),
        compiler.CommandColor.OBJECT: (utils.rgba('rgb(100, 100, 100)'),
                                       _white),
        compiler.CommandColor.TYPE_CONV: (_default_bg,
                                          _black),
    }
    return colors


def validate_color_scheme(scheme: compiler.CommandColorScheme):
    for c in compiler.CommandColor:
        if c not in scheme:
            raise Exception(f'Color {c} is missing in the color scheme!')


def prepare_drag(source: Gtk.DragSource,
                 commands: compiler.CodePiece,
                 widget: Gtk.Widget,
                 colors: compiler.CommandColorScheme) -> Gdk.ContentProvider:
    val = GObject.Value()
    val.init(compiler.CodePieceDrop)
    drop = compiler.CodePieceDrop(compiler.save_codepice(commands))
    val.set_value(drop)
    cp = Gdk.ContentProvider.new_for_value(val)

    snapshot = Gtk.Snapshot.new()
    width, height = append_block_to_snapshot(
        commands, snapshot, 0, 0, widget, colors)
    size = Graphene.Size().init(width, height)
    paintable = snapshot.to_paintable(size)
    source.set_icon(
        paintable, ICON_WIDTH / 2, ICON_HEIGHT / 2)

    return cp


GObject.type_register(SingleIconWidget)
