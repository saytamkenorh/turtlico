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
from abc import abstractmethod
from enum import Enum
from typing import Callable

from gi.repository import Gtk, Gdk, Pango

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

        self.props.resizable = False

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


class StringType(Enum):
    STRING = 0
    VARIABLE_NAME = 1
    PYTHON = 2
    PATH = 3


_STRING_TYPES = {
    'str': StringType.STRING,
    'obj': StringType.VARIABLE_NAME,
    'tc': StringType.PYTHON,
    'img': StringType.PATH
}


class StringDialog(DataEditorDialog):
    _string_entry: Gtk.Entry

    def __init__(self, str_type: StringType):
        super().__init__()
        content = self.get_content_area()

        self._string_entry = Gtk.Entry.new()
        self._string_entry.props.hexpand = True
        if str_type == StringType.PATH:
            self._string_entry.props.input_purpose = Gtk.InputPurpose.URL
        self._string_entry.connect('activate', self._on_activate)

        content.append(self._string_entry)

    def get_data(self) -> str:
        return self._string_entry.get_text()

    def set_data(self, data: str):
        if data:
            self._string_entry.set_text(data)
        else:
            self._string_entry.set_text('')

    def _on_activate(self, widget):
        self.emit('response', Gtk.ResponseType.OK)


class PythonDialog(DataEditorDialog):
    _code_view: Gtk.TextView
    _scrolled_window: Gtk.ScrolledWindow

    def __init__(self):
        super().__init__()
        content = self.get_content_area()

        self._code_view = Gtk.TextView.new()

        self._scrolled_window = Gtk.ScrolledWindow.new()
        self._scrolled_window.props.hexpand = True
        self._scrolled_window.set_child(self._code_view)

        content.append(self._scrolled_window)
        content.props.vexpand = True
        content.props.valign = Gtk.Align.FILL

        self.set_default_size(300, 200)

    def get_data(self) -> str:
        return self._code_view.props.buffer.props.text

    def set_data(self, data: str):
        if data:
            self._code_view.props.buffer.props.text = data
        else:
            self._code_view.props.buffer.props.text = ''


class ColorDialog(DataEditorDialog):
    _color_chooser: Gtk.ColorChooserWidget

    def __init__(self):
        super().__init__()
        content = self.get_content_area()

        self._color_chooser = Gtk.ColorChooserWidget.new()
        self._color_chooser.props.use_alpha = False
        content.append(self._color_chooser)

    def get_data(self) -> str:
        c = self._color_chooser.props.rgba
        cstr = f'{int(c.red * 255)},{int(c.green * 255)},{int(c.blue * 255)}'
        return cstr

    def set_data(self, data: str):
        if data:
            rgba = utils.rgba(f'rgb({data})')
        else:
            rgba = utils.rgba('rgb(0,0,0)')
        self._color_chooser.props.rgba = rgba


_FONT_TYPES = {
    'normal': Pango.Style.NORMAL,
    'italic': Pango.Style.ITALIC
}
_FONT_TYPES_CODES = dict(map(reversed, _FONT_TYPES.items()))
_FONT_WEIGHTS = {
    'normal': Pango.Weight.NORMAL,
    'bold': Pango.Weight.BOLD
}
_FONT_WEIGHTS_CODES = dict(map(reversed, _FONT_WEIGHTS.items()))


class FontDialog(DataEditorDialog):
    _font_chooser: Gtk.FontChooserWidget

    def __init__(self):
        super().__init__()
        content = self.get_content_area()

        self._font_chooser = Gtk.FontChooserWidget.new()
        self._font_chooser.set_filter_func(self._font_filter)
        content.append(self._font_chooser)

    def get_data(self) -> str:
        f = self._font_chooser.props.font_desc
        family = f.get_family()
        size = int(f.get_size() / Pango.SCALE)
        fonttype = _FONT_TYPES_CODES.get(f.get_style(), 'normal')
        weight = _FONT_WEIGHTS_CODES.get(f.get_weight(), 'normal')
        fstr = f'{family};{size};{fonttype};{weight}'
        return fstr

    def set_data(self, data: str):
        if data:
            family, size, fonttype, weight = data.split(';')
            font = Pango.FontDescription.new()
            font.set_family(family)
            font.set_size(int(size) * Pango.SCALE)
            font.set_style(_FONT_TYPES.get(fonttype, Pango.Style.NORMAL))
            font.set_weight(_FONT_WEIGHTS.get(weight, Pango.Weight.NORMAL))

            self._font_chooser.props.font_desc = font

    def _font_filter(self,
                     family: Pango.FontFamily,
                     face: Pango.FontFace) -> bool:
        desc = face.describe()
        if desc.get_style() not in _FONT_TYPES.values():
            return False
        if desc.get_weight() not in _FONT_WEIGHTS.values():
            return False
        return True


class KeyDialog(DataEditorDialog):
    _image: Gtk.Image
    _label: Gtk.Label

    _key_ctl: Gtk.EventControllerKey

    def __init__(self):
        super().__init__()
        content = self.get_content_area()
        content.props.orientation = Gtk.Orientation.VERTICAL

        self._image = Gtk.Image.new_from_icon_name(
            'preferences-desktop-keyboard-shortcuts-symbolic')
        self._image.props.pixel_size = 64
        content.append(self._image)

        self._label = Gtk.Label.new('')
        self._label.get_style_context().add_class('title-3')
        content.append(self._label)

        self._key_ctl = Gtk.EventControllerKey.new()
        self._key_ctl.props.propagation_phase = Gtk.PropagationPhase.CAPTURE
        self._key_ctl.connect('key_pressed', self._on_key_pressed)
        self.add_controller(self._key_ctl)

    def get_data(self) -> str:
        return self._label.props.label

    def set_data(self, data: str):
        self._label.props.label = data

    def _on_key_pressed(self, widget,
                        keyval, keycode, state: Gdk.ModifierType):
        # Allow close the dialog using only keyboard
        ctrl = state & Gdk.ModifierType.CONTROL_MASK
        if ctrl != 0 and keyval == Gdk.KEY_Escape:
            self.emit('response', Gtk.ResponseType.CANCEL)
            return True

        key: str = Gdk.keyval_name(keyval)
        self._label.props.label = key
        return True


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
    elif cid == 'color':
        dialog = ColorDialog()
    elif cid == 'font':
        dialog = FontDialog()
    elif cid == 'key':
        dialog = KeyDialog()
    elif cmd.definition.command_type == compiler.CommandType.LITERAL:
        str_type = _STRING_TYPES.get(cmd.definition.id, StringType.STRING)
        dialog = StringDialog(str_type)
    elif cmd.definition.id == 'python':
        dialog = PythonDialog()
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
