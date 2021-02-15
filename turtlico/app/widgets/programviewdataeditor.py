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

import sys
from typing import Callable
from abc import abstractmethod

from gi.repository import Gtk

import turtlico.compiler as compiler
import turtlico.utils as utils
from turtlico.locale import _


class DataEditorDialog(Gtk.Dialog):
    def __init__(self):
        super().__init__(
            use_header_bar=sys.platform == 'linux'
        )
        self.set_modal(True)
        self.add_button(_('Cancel'), Gtk.ResponseType.CANCEL)
        self.add_button(_('Done'), Gtk.ResponseType.OK)
        self.set_default_response(Gtk.ResponseType.OK)
        self.props.title = ''

        content = self.get_content_area()
        content.props.valign = Gtk.Align.CENTER
        content.props.vexpand = True
        content.props.margin_start = 10
        content.props.margin_end = 10
        content.props.margin_top = 10
        content.props.margin_bottom = 10

    @abstractmethod
    def get_data(self):
        pass

    @abstractmethod
    def set_data(self, data: str):
        pass


class NumberDialog(DataEditorDialog):
    _number_entry: Gtk.SpinButton

    def __init__(self):
        super().__init__()
        content = self.get_content_area()

        float_info = sys.float_info
        self._number_entry = Gtk.SpinButton.new_with_range(
            float_info.min,
            float_info.max,
            1
        )
        self._number_entry.props.hexpand = True
        self._number_entry.props.snap_to_ticks = False
        self._number_entry.props.digits = 3

        self._shortcut_controller = Gtk.ShortcutController()
        self._shortcut_controller.props.scope = Gtk.ShortcutScope.GLOBAL
        self._shortcut_controller.props.propagation_phase = (
            Gtk.PropagationPhase.CAPTURE)
        self._shortcut_controller.add_shortcut(
            utils.new_shortcut("Return|KP_Enter", self._on_editing_done))
        self.add_controller(self._shortcut_controller)

        content.append(self._number_entry)

    def get_data(self) -> str:
        val = self._number_entry.props.value
        if val.is_integer():
            return str(round(val))
        return str(round(val, 3))

    def set_data(self, data: str):
        if not data:
            self._number_entry.props.value = 0
        else:
            self._number_entry.props.value = float(data)

    def _on_editing_done(self, widget, data):
        self._number_entry.update()
        self.emit('response', Gtk.ResponseType.OK)


def _edit_icon_finish(dialog: DataEditorDialog,
                      response: Gtk.ResponseType,
                      project: compiler.ProjectBuffer,
                      cmd: compiler.Command,
                      callback: Callable[[compiler.Command], None],
                      user_data):
    if response != Gtk.ResponseType.OK:
        callback(cmd, *user_data)
        dialog.destroy()
        return

    data = dialog.get_data()
    if data != cmd.data:
        cmd = project.set_command_data(cmd, data)
    callback(cmd, *user_data)
    dialog.destroy()


def edit_icon(cmd: compiler.Command,
              project: compiler.ProjectBuffer,
              parent: Gtk.Window,
              callback: Callable[[compiler.Command], None],
              *user_data):
    dialog: DataEditorDialog = None
    cid = cmd.definition.id

    if cid == 'int':
        dialog = NumberDialog()
    else:
        callback(cmd, *user_data)
        return

    dialog.set_transient_for(parent)
    dialog.set_data(cmd.data)
    dialog.connect(
        'response',
        _edit_icon_finish, project, cmd,
        callback, user_data)
    dialog.show()
