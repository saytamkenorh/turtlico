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
from turtlico.app.debugger import Debugger, DebuggingReuslt
import turtlico.app.widgets as widgets
from turtlico.locale import _


@Gtk.Template(resource_path='/io/gitlab/Turtlico/ui/mainwindow.ui')
class MainWindow(Gtk.ApplicationWindow):
    __gtype_name__ = 'TurtlicoMainWindow'

    _icon_view: widgets.IconsView = Gtk.Template.Child()
    _program_view: widgets.programview = Gtk.Template.Child()
    _status_bar: Gtk.Label = Gtk.Template.Child()

    _run_btn = Gtk.Template.Child()
    _run_btn_img = Gtk.Template.Child()

    _run_action: Gio.SimpleAction

    buffer: compiler.ProjectBuffer
    compiler: compiler.Compiler
    icon_colors: compiler.CommandColorScheme
    debugger: Debugger

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.debugger = None
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

        self._run_btn_set_running(False)

    def _on_run(self, action, params):
        if self.debugger and self.debugger.props.running:
            self.debugger.stop()
            return
        self.debugger = Debugger(self.buffer, self.compiler)
        self.debugger.connect('debugging-done', self._on_debugging_done)
        self._run_btn_set_running(True)
        self.debugger.run()

    def _run_btn_set_running(self, running: bool):
        if running:
            self._run_btn_img.props.icon_name = 'media-playback-stop-symbolic'
            self._run_btn.props.tooltip_text = _('Stop')
        else:
            self._run_btn_img.props.icon_name = 'media-playback-start-symbolic'
            self._run_btn.props.tooltip_text = _('Run')

    def _on_debugging_done(self, debugger, result: DebuggingReuslt):
        self.debugger.dispose()
        self.debugger = None
        self._run_btn_set_running(False)

        if result.props.program_failed:
            dialog = Gtk.MessageDialog(
                transient_for=self,
                modal=True,
                buttons=Gtk.ButtonsType.OK,
                text=_('Program crashed'),
                secondary_text=result.props.error_message,
                message_type=Gtk.MessageType.ERROR)
            dialog.show()

            def close(dialog, reposne):
                dialog.close()

            dialog.connect('response', close)
