# main.py
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
import gi

gi.require_version('Gtk', '4.0')

from gi.repository import Gtk, Gio

from .windows.mainwindow import MainWindow


class Application(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='io.gitlab.Turtlico',
                         flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)

    def do_activate(self):
        self._set_actions()
        self.make_window().present()

    def make_window(self):
        win = self.props.active_window
        if not win:
            win = MainWindow(application=self)
        return win

    def do_command_line(self, command_line):
        options = command_line.get_options_dict()
        # convert GVariantDict -> GVariant -> dict
        options = options.end().unpack()

        win = self.make_window()
        do_present = True

        if do_present:
            win.present()

        if len(command_line.get_arguments()) >= 2 and do_present:
            _file = os.path.abspath(command_line.get_arguments()[1])
            win.open_local_file(_file)

        return 0

    def _set_actions(self):
        action_entries = [
            ('about', self._about, None),
            ('help', self._help, None),
            ('quit', self._quit, ('app.quit', ['<Ctrl>Q']))
        ]

        for action, callback, accel in action_entries:
            simple_action = Gio.SimpleAction.new(action, None)
            simple_action.connect('activate', callback)
            self.add_action(simple_action)
            if accel is not None:
                self.set_accels_for_action(*accel)
