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

import gi

gi.require_version('Gtk', '4.0')
from gi.repository import Gio, Gtk

import turtlico.compiler as compiler
import turtlico.utils as utils
import turtlico.app.widgets as widgets


@Gtk.Template(resource_path='/io/gitlab/Turtlico/ui/mainwindow.ui')
class MainWindow(Gtk.ApplicationWindow):
    __gtype_name__ = 'TurtlicoMainWindow'

    _icon_view: widgets.IconsView = Gtk.Template.Child()
    _program_view: widgets.programview = Gtk.Template.Child()
    _status_bar: Gtk.Label = Gtk.Template.Child()

    _run_action: Gio.SimpleAction

    buffer: compiler.ProjectBuffer
    compiler: compiler.Compiler
    icon_colors: compiler.CommandColorScheme

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.buffer = compiler.ProjectBuffer()
        self.compiler = compiler.Compiler(self.buffer)
        self.icon_colors = widgets.get_default_colors()

        self._icon_view.set_colors(self.icon_colors)
        self._icon_view.props.project_buffer = self.buffer

        self._program_view.set_colors(self.icon_colors)
        self._program_view.set_codebuffer(self.buffer.code)
        self._program_view.bind_property(
            'status-tooltip', self._status_bar, 'label')

        # Actions
        self._run_action = Gio.SimpleAction.new("project.run", None)
        self._run_action.connect('activate', self._on_run)
        self.add_action(self._run_action)

    def _on_run(self, action, params):
        code, debug_map = self.compiler.compile(self.buffer.code.lines)
        utils.debug('Generated code:')
        utils.debug(code)
