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
from typing import Union

from gi.repository import GObject, Gtk, Gdk, Graphene

import turtlico.compiler as compiler
from .icon import (append_block_to_snapshot, prepare_drag,
                   ICON_WIDTH, ICON_HEIGHT)


class ProgramView(Gtk.Widget, Gtk.Scrollable):
    __gtype_name__ = 'TurtlicoProgramView'

    _selection: compiler.CodePieceSelection

    @GObject.Property(type=compiler.CodePieceSelection)
    def selection(self):
        return self._selection

    @selection.setter
    def selection(self, value):
        self._selection = value
        self.queue_draw()

    _codebuffer: compiler.CodeBuffer
    _codebuffer_code_changed_id: int
    _colors: compiler.CommandColorScheme

    _drag_source: Gtk.DragSource
    _drag_source_copy: Gtk.DragSource
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

    @hadjustment.setter
    def hadjustment(self, value):
        self._hadjustment = value
        self._hadjustment.step_increment = ICON_WIDTH
        self._hadjustment.connect('value-changed', self._on_adjustment_value_changed)
        self._update_hadjustment()

    @GObject.Property(type=Gtk.Adjustment)
    def vadjustment(self):
        return self._vadjustment

    @vadjustment.setter
    def vadjustment(self, value):
        self._vadjustment = value
        self._vadjustment.step_increment = ICON_HEIGHT
        self._vadjustment.connect('value-changed', self._on_adjustment_value_changed)
        self._update_vadjustment()

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.props.selection = None

        self._codebuffer = None
        self._colors = None

        self._drag_source = Gtk.DragSource.new()
        self._drag_source.props.actions = Gdk.DragAction.MOVE
        self._drag_source.connect('prepare', self._on_drag_prepare)
        self._drag_source.connect('drag_end', self._on_drag_end)
        self.add_controller(self._drag_source)

        self._drag_source_copy = Gtk.DragSource.new()
        self._drag_source_copy.props.actions = Gdk.DragAction.COPY
        self._drag_source_copy.props.button = Gdk.BUTTON_SECONDARY
        self._drag_source_copy.connect('prepare', self._on_drag_prepare)
        self._drag_source_copy.connect('drag_end', self._on_drag_end)
        self.add_controller(self._drag_source_copy)

        self._drop_target = Gtk.DropTarget.new(
            compiler.CodePieceDrop, Gdk.DragAction.COPY | Gdk.DragAction.MOVE)
        self._drop_target.connect('drop', self._on_drop_target_drop)
        self.add_controller(self._drop_target)

    def do_snapshot(self, snapshot: Gtk.Snapshot):
        if not self._colors:
            return
        area = Graphene.Rect().init(0, 0, self.get_width(), self.get_height())

        # Contenxt scroll
        tx = -int(self.hadjustment.props.value)
        ty = -int(self.vadjustment.props.value)

        snapshot.append_color(
            self._colors[compiler.CommandColor.INDENTATION][0], area)
        if not self._codebuffer:
            return

        snapshot.push_clip(area)
        start_x = int(self.hadjustment.props.value / ICON_WIDTH)
        end_x = math.ceil(self.hadjustment.props.value + self.get_width() / ICON_WIDTH)
        start_y = int(self.vadjustment.props.value / ICON_HEIGHT)
        end_y = math.ceil(self.vadjustment.props.value + self.get_height() / ICON_HEIGHT)
        append_block_to_snapshot(self._codebuffer.lines,
                                 snapshot, tx, ty,
                                 self, self._colors, None,
                                 start_x, end_x, start_y, end_y)
        snapshot.pop()

    def do_size_allocate(self, width: int, height: int, baseline: int):
        self._update_adjustments()

    def do_measure(self, orientation, for_size):
        if orientation == Gtk.Orientation.HORIZONTAL:
            width = self.hadjustment.props.upper
            return (width, width, -1, -1)
        else:
            height = self.vadjustment.props.upper
            return (height, height, -1, -1)

    def _update_adjustments(self):
        self._update_hadjustment()
        self._update_vadjustment()

    def _update_hadjustment(self):
        if not self.props.hadjustment:
            self.props.hadjustment = Gtk.Adjustment.new(0, 0, 0, 0, 0, 0)
        width  = 3
        if self._codebuffer and len(self._codebuffer.lines) > 0:
            width += (max(
                [len(line) for line in self._codebuffer.lines]))
        width *= ICON_WIDTH

        self.props.hadjustment.props.lower = 0
        self.props.hadjustment.props.upper = width
        self.props.hadjustment.props.page_size = min(width, self.get_width())
        self.props.hadjustment.props.value = min(
            self.props.hadjustment.props.value,
            width - self.props.hadjustment.props.page_size
        )

    def _update_vadjustment(self):
        if not self.props.vadjustment:
            self.props.vadjustment = Gtk.Adjustment.new(0, 0, 0, 0, 0, 0)
        height = 3
        if self._codebuffer:
            height += len(self._codebuffer.lines)
        height *= ICON_HEIGHT

        self.props.vadjustment.props.lower = 0
        self.props.vadjustment.props.upper = height
        self.props.vadjustment.props.page_size = min(height, self.get_height())
        self.props.vadjustment.props.value = min(
            self.props.vadjustment.props.value,
            height - self.props.vadjustment.props.page_size
        )

    def _on_adjustment_value_changed(self, adjustment):
        self.queue_draw()

    def do_get_request_mode(self):
        return Gtk.SizeRequestMode.CONSTANT_SIZE

    def get_command_at(self, x: float, y: float
                       ) -> Union[tuple[compiler.Command, int, int], None]:
        """Return Command at widget position x,y

        Args:
            x (float): X coordinate in pixels
            y (float): Y coordinate in pixels

        Returns:
            Union[compiler.Command, None]: The Command or None
        """
        x, y = self._get_program_coords(x, y)
        if y >= len(self._codebuffer.lines):
            return (None, None, None)
        if x >= len(self._codebuffer.lines[y]):
            return (None, None, None)
        return (self._codebuffer.lines[y][x], x, y)

    def drop_coords_to_program(self, x: float, y: float) -> (int, int):
        """Returns a position in program
            where should be inserted icons that were dropped at x,y

        Args:
            x (float): X coordinate in pixels
            y (float): Y coordinate in pixels

        Returns:
            (int, int): Line number and column number
        """
        x, y = self._get_program_coords(x, y)
        lineslen = len(self._codebuffer.lines)

        y = min(y, lineslen)
        if y == -1:
            return (0, 0)
        if y >= lineslen:
            return (0, y)

        x = min(x, len(self._codebuffer.lines[y]) - 1)
        return (x, y)

    def _get_program_coords(self, x: float, y: float) -> (int, int):
        """Converts mouse coordinates to icon column and line

        Args:
            x (float): X coordinate in pixels
            y (float): Y coordinate in pixels

        Returns:
            (int, int): Icon column and line
        """
        x += self.props.hadjustment.props.value
        y += self.props.vadjustment.props.value
        x = math.floor(x / ICON_WIDTH)
        y = math.floor(y / ICON_HEIGHT)
        return (x, y)

    def set_codebuffer(self, codebuffer: compiler.CodeBuffer):
        assert isinstance(codebuffer, compiler.CodeBuffer)

        if self._codebuffer:
            self._codebuffer.disconnect(self._codebuffer_code_changed_id)
        self._codebuffer = codebuffer
        sid = self._codebuffer.connect(
            'code-changed', self._codebuffer_code_changed)
        self._codebuffer_code_changed_id = sid
        self.queue_draw()

    def set_colors(self, colors: compiler.CommandColorScheme):
        self._colors = colors
        self.queue_draw()

    def delete_selection(self):
        self._codebuffer.delete(self.props.selection)
        self.props.selection = None

    def _on_drop_target_drop(self,
                             dt: Gtk.DropTarget,
                             drop: compiler.CodePieceDrop, x, y
                             ):
        if not self._codebuffer:
            return False

        # In local transfers deletes moved icon first before inserting it again
        local_drag = self._drag_source.get_drag()
        if (dt.get_drop().get_drag() == local_drag
                and local_drag.props.selected_action == Gdk.DragAction.MOVE):
            self.delete_selection()

        commands = compiler.load_codepiece(
            drop.tcppiece, self._codebuffer.project)
        x, y = self.drop_coords_to_program(x, y)

        self._codebuffer.insert(commands, x, y)
        return True

    def _codebuffer_code_changed(self, codebuffer):
        self._update_adjustments()
        self.queue_draw()

    def _on_drag_prepare(self,
                         source: Gtk.DragSource, x: float, y: float
                         ) -> Gdk.ContentProvider:
        if self.props.selection:
            # TODO: Implement selection
            commands = []
        else:
            command, cx, cy = self.get_command_at(x, y)
            if not command:
                return None
            commands = [[command]]
            self.props.selection = compiler.CodePieceSelection(cx, cy, cx, cy)

        return prepare_drag(source, commands, self, self._colors)

    def _on_drag_end(self,
                     source: Gtk.DragSource,
                     drag: Gdk.Drag, delete_data: bool):
        if delete_data and self.props.selection:
            self.delete_selection()
        self.props.selection = None


GObject.type_register(ProgramView)
