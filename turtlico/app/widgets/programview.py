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
from collections import namedtuple
from typing import Union

from gi.repository import GObject, Gtk, Gdk, Graphene

import turtlico.compiler as compiler
import turtlico.utils as utils

from .icon import (append_block_to_snapshot, prepare_drag,
                   validate_color_scheme,
                   ICON_WIDTH, ICON_HEIGHT)
from .programviewdataeditor import edit_icon

SelectionStart = namedtuple('SelectionStart', ['mouse_x', 'mouse_y', 'x', 'y'])


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

    selection_color = GObject.Property(type=Gdk.RGBA)
    status_tooltip = GObject.Property(type=str)

    _codebuffer: compiler.CodeBuffer
    _codebuffer_code_changed_id: int
    _colors: compiler.CommandColorScheme

    _drag_source: Gtk.DragSource
    _drag_source_copy: Gtk.DragSource
    _drop_target: Gtk.DropTarget
    _drag_selection: Gtk.GestureDrag
    _motion_controller: Gtk.EventControllerMotion
    _hadjustment: Gtk.Adjustment
    _hscroll_policy: Gtk.ScrollablePolicy
    _shortcut_controller: Gtk.ShortcutController
    _vadjustment: Gtk.Adjustment
    _vscroll_policy: Gtk.ScrollablePolicy

    _drag_selection_start: SelectionStart
    _last_ptr_pos: Union[(int, int), None]

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
        self._hadjustment.connect('value-changed',
                                  self._on_adjustment_value_changed)
        self._update_hadjustment()

    @GObject.Property(type=Gtk.Adjustment)
    def vadjustment(self):
        return self._vadjustment

    @vadjustment.setter
    def vadjustment(self, value):
        self._vadjustment = value
        self._vadjustment.step_increment = ICON_HEIGHT
        self._vadjustment.connect('value-changed',
                                  self._on_adjustment_value_changed)
        self._update_vadjustment()

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._codebuffer = None
        self._colors = None
        self._drag_selection_start = None
        self._last_ptr_pos = None

        self.props.has_tooltip = True

        self.props.selection = None
        self.props.selection_color = utils.rgba('rgba(0, 0, 0, 0.35)')
        self.connect('notify::selection-color',
                     self._on_selection_color_notify)

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

        self._drag_selection = Gtk.GestureDrag.new()
        self._drag_selection.connect('drag-begin', self._on_selection_begin)
        self._drag_selection.connect('drag-update', self._on_selection_update)
        self._drag_selection.connect('drag-end', self._on_selection_end)
        self.add_controller(self._drag_selection)

        self._shortcut_controller = Gtk.ShortcutController()
        self._shortcut_controller.props.scope = Gtk.ShortcutScope.GLOBAL
        self._shortcut_controller.add_shortcut(
            utils.new_shortcut('Delete', self._on_delete_shortcut))
        self._shortcut_controller.add_shortcut(
            utils.new_shortcut('F2', self._on_edit_shortcut))
        self.add_controller(self._shortcut_controller)

        self._motion_controller = Gtk.EventControllerMotion()
        self._motion_controller.connect('motion', self._on_ptr_motion)
        self._motion_controller.connect('leave', self._on_ptr_leave)
        self.add_controller(self._motion_controller)

    def do_snapshot(self, snapshot: Gtk.Snapshot):
        if not self._colors:
            return
        area = Graphene.Rect().init(0, 0, self.get_width(), self.get_height())

        snapshot.append_color(
            self._colors[compiler.CommandColor.INDENTATION][0], area)
        if not self._codebuffer:
            return

        # Content
        snapshot.push_clip(area)
        # Scroll
        tx = -int(self.hadjustment.props.value)
        ty = -int(self.vadjustment.props.value)
        start_x = int(self.hadjustment.props.value / ICON_WIDTH)
        end_x = math.ceil(self.hadjustment.props.value
                          + self.get_width() / ICON_WIDTH)
        start_y = int(self.vadjustment.props.value / ICON_HEIGHT)
        end_y = math.ceil(self.vadjustment.props.value
                          + self.get_height() / ICON_HEIGHT)

        append_block_to_snapshot(self._codebuffer.lines,
                                 snapshot, tx, ty,
                                 self, self._colors, None,
                                 start_x, end_x, start_y, end_y)
        # Selection
        if self.props.selection:
            start_y = self.props.selection.start_y
            end_y = self.props.selection.end_y
            for y in range(start_y, end_y + 1):
                start_x = 0 if y > start_y else self.props.selection.start_x
                end_x = (len(self._codebuffer.lines[y]) - 1 if y < end_y
                         else self.props.selection.end_x)
                selection_rect = Graphene.Rect().init(
                    tx + start_x * ICON_WIDTH, ty + y * ICON_HEIGHT,
                    (end_x - start_x + 1) * ICON_WIDTH,
                    ICON_HEIGHT
                )
                snapshot.append_color(
                    self.props.selection_color,
                    selection_rect)

        snapshot.pop()
        snapshot.render_focus(self.get_style_context(), 0, 0,
                              self.get_width(), self.get_height())

    def do_size_allocate(self, width: int, height: int, baseline: int):
        self._update_adjustments()

    def do_measure(self, orientation, for_size):
        if orientation == Gtk.Orientation.HORIZONTAL:
            width = self.hadjustment.props.upper
            return (width, width, -1, -1)
        else:
            height = self.vadjustment.props.upper
            return (height, height, -1, -1)

    def do_query_tooltip(self,
                         x, y,
                         keyboard_tooltip: bool,
                         tooltip: Gtk.Tooltip) -> bool:
        cmd = self.get_command_at(x, y)[0]
        if cmd is None or not cmd.data:
            return False
        tooltip.set_text(cmd.data)
        return True

    def _update_adjustments(self):
        self._update_hadjustment()
        self._update_vadjustment()

    def _update_hadjustment(self):
        if not self.props.hadjustment:
            self.props.hadjustment = Gtk.Adjustment.new(0, 0, 0, 0, 0, 0)
        width = 3
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
                       ) -> tuple[compiler.Command, int, int]:
        """Return Command at widget position x,y

        Args:
            x (float): X coordinate in pixels
            y (float): Y coordinate in pixels

        Returns:
            tuple[compiler.Command, int, int]:
                The Command (or None) and its coords
        """
        x, y = self._get_program_coords(x, y)
        if y >= len(self._codebuffer.lines) or y < 0:
            return (None, x, y)
        if x >= len(self._codebuffer.lines[y]) or x < 0:
            return (None, x, y)
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
        try:
            validate_color_scheme(colors)
        except Exception as e:
            compiler.error(e)
        self._colors = colors
        self.queue_draw()

    def delete_selection(self):
        self._codebuffer.delete(self.props.selection)
        self.props.selection = None

    def edit_command(self, x, y):
        assert y < len(self._codebuffer.lines)
        assert x < len(self._codebuffer.lines[y])

        cmd = self._codebuffer.lines[y][x]
        edit_icon(
            cmd, self._codebuffer.project, self._get_parent_window(),
            self._on_edit_command_response, x, y)

    def _on_edit_command_response(self, cmd: compiler.Command, x, y):
        self._codebuffer.replace_command(cmd, x, y)
        self.queue_draw()

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
        self.props.selection = None

    def _on_drag_prepare(self,
                         source: Gtk.DragSource, x: float, y: float
                         ) -> Gdk.ContentProvider:
        shift_mask = (source.get_current_event_state()
                      & Gdk.ModifierType.SHIFT_MASK)
        if shift_mask != 0:
            return None
        if self.props.selection:
            commands = self._codebuffer.get_range(self.props.selection)
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

    def _on_selection_color_notify(self, obj, prop):
        self.queue_draw()

    def _on_selection_begin(self,
                            source: Gtk.GestureDrag,
                            start_x: float, start_y: float):
        cmd, x, y = self.get_command_at(start_x, start_y)
        shift_mask = (source.get_current_event_state()
                      & Gdk.ModifierType.SHIFT_MASK)
        if cmd is None:
            self.props.selection = None
            return
        if shift_mask == 0:
            self._drag_selection_start = None
            return
        self.props.selection = compiler.CodePieceSelection(x, y, x, y)
        self._drag_selection_start = SelectionStart(
            start_x, start_y, x, y
        )

    def _on_selection_update(self,
                             source: Gtk.GestureDrag,
                             offset_x: float, offset_y: float):
        if ((self.selection is None)
                or (self._drag_selection_start is None)):
            return
        sx = self._drag_selection_start.x
        sy = self._drag_selection_start.y
        ex, ey = self._get_program_coords(
            self._drag_selection_start.mouse_x + offset_x,
            self._drag_selection_start.mouse_y + offset_y
        )

        ey = min(len(self._codebuffer.lines) - 1, ey)
        if ey < 0:
            return
        ex = min(len(self._codebuffer.lines[ey]) - 1, ex)
        if ex < 0:
            return

        self.props.selection = compiler.CodePieceSelection(sx, sy, ex, ey)

    def _on_selection_end(self,
                          source: Gtk.GestureDrag,
                          offset_x: float, offset_y: float):
        self._drag_selection_start = None

    def _on_delete_shortcut(self, widget, args):
        if self.props.selection is not None:
            self.delete_selection()
            return
        if self._last_ptr_pos is None:
            return
        x, y = self._last_ptr_pos
        cmd, cx, cy = self.get_command_at(x, y)
        if cmd is None:
            return
        self.props.selection = compiler.CodePieceSelection(cx, cy, cx, cy)
        self.delete_selection()

    def _on_ptr_motion(self, widget, x, y):
        cmd, cx, cy = self.get_command_at(x, y)
        if cmd is None:
            self.props.status_tooltip = ''
        else:
            self.props.status_tooltip = '{}:{} {}'.format(
                cy + 1, cx + 1, cmd.definition.help)
        self._last_ptr_pos = (x, y)

    def _on_ptr_leave(self, widget):
        self.props.status_tooltip = ''
        self._last_ptr_pos = None

    def _on_edit_shortcut(self, widget, args):
        if self._last_ptr_pos is None:
            return
        x, y = self._last_ptr_pos
        cmd, cx, cy = self.get_command_at(x, y)
        if cmd is None:
            return
        self.edit_command(cx, cy)

    def _get_parent_window(self) -> Union[Gtk.Window, None]:
        w = None
        p = self
        while p := p.get_parent():
            w = p
        if w == self or not isinstance(w, Gtk.Window):
            return None
        return w


GObject.type_register(ProgramView)
