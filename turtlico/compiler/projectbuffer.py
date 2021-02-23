# projectbuffer.py
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

from __future__ import annotations

from gi.repository import Gio, GObject

from turtlico.compiler.codepiece import CodeBuffer, parse_tcp, save_tcp
from turtlico.compiler.command import Command, Plugin
import turtlico.compiler.legacy as legacy

FILE_VERSION_FORMAT = 2
DEFAULT_PROJECT = [('fver', FILE_VERSION_FORMAT), ('plugin', 'turtle')]


class CorruptedFileException(Exception):
    pass


class MissingPluginException(Exception):
    pass


class ProjectBuffer(GObject.Object):
    """Contains information about a project"""

    __gtype_name__ = "ProjectBuffer"

    enabled_plugins: dict[str, Plugin]
    code: CodeBuffer
    available_commands: dict[str, Command]
    run_in_console: bool
    _project_file: Gio.File

    @GObject.Property(type=Gio.File)
    def project_file(self):
        """The Gio.File of currently opened project"""
        return self._project_file

    @project_file.setter
    def project_file(self, value):
        self._project_file = value

    @GObject.Signal
    def available_commands_changed(self):
        pass

    def __init__(self):
        super().__init__()
        self.enabled_plugins = {}
        self.available_commands = {}
        self.code = CodeBuffer(
            project=self, record_history=True, code=None)
        self.load_from_file(file=None)

    def load_from_file(self, file: Gio.File, ignore_errors=False):
        # Get list of available plugins
        available_plugins = {}
        for p in Plugin.get_paths():
            available_plugins[Plugin.get_id_from_path(p)] = p
        enabled_plugins = []
        # Base is enabled by default
        enabled_plugins.append(available_plugins['base'])

        if file is not None:
            # Reads the file
            file_dis = Gio.DataInputStream(file.read())
            source = file_dis.read_upto('\0', 1)[0]
            file_dis.close()
            # Parses the file
            project = parse_tcp(source)
        else:
            project = DEFAULT_PROJECT.copy()

        # Reset variables
        self.run_in_console = False
        self.props.project_file = file

        # Load project
        # project_code contains only commands (without meta-info like plugin)
        project_code = []
        # IDs of plugins that are requested to load
        plugin_ids = ['base']
        file_version = 0

        for cmd in project:
            if len(cmd) != 2:
                raise CorruptedFileException()
            id = cmd[0]
            data = cmd[1]
            if id == 'plugin':
                plugin_id = Plugin.get_id_from_path(data)
                plugin_ids.append(plugin_id)
            elif id == 'fver':
                file_version = int(data)
            elif id == 'fconsole':
                self.run_in_console = bool(data)
            else:
                project_code.append(cmd)

        if file_version <= 0 and 'turtle' not in enabled_plugins:
            enabled_plugins.append('turtle')

        if file_version <= 1:
            project = legacy.tcp_1_to_2(source, plugin_ids)

        for plugin_id in plugin_ids:
            if plugin_id in available_plugins:
                enabled_plugins.append(available_plugins[plugin_id])
            elif not ignore_errors:
                raise MissingPluginException(plugin_id)

        self._reload_plugins(enabled_plugins)
        self.code.load(project_code, ignore_errors)

    def save(self) -> bool:
        if self.project_file is None:
            raise Exception(
                'Project has not been saved yet. Please use save_as instead.')
        return self.save_as(self.project_file)

    def save_as(self, file: Gio.File) -> bool:
        output = []

        # Meta-info
        output.append(('fver', str(FILE_VERSION_FORMAT)))
        for p in self.enabled_plugins:
            # Base is enabled by default
            if p.id == 'base':
                continue
            output.append(('plugin', p.id))
        output.append(('fconsole'), str(self.run_in_console))

        # Commands
        output.extend(self.code.save())

        outs = file.open_readwrite()
        content = save_tcp(output)
        ok, bytes_written = outs.write_all(content)
        return ok

    def _update_available_commands(self):
        self.available_commands.clear()
        for p in self.enabled_plugins.values():
            for c in p.categories:
                for cdefin in c.command_definitions:
                    self.available_commands[cdefin.id] = Command(
                        None, cdefin)
        self.emit('available_commands_changed')

    def _reload_plugins(self, enabled_plugins: list[str] = None):
        """enabled_plugins: New list of enabled plugin ids.
                            None to reload currently enabled plugins."""
        if not enabled_plugins:
            enabled_plugins = self.enabled_plugins.keys()
        self.enabled_plugins = Plugin.get_from_paths(
            enabled_plugins)
        self._update_available_commands()

    def get_command(self, id, data) -> tuple[Command, bool]:
        command = self.available_commands.get(id, None)
        if command is None:
            return (None, False)
        if not data:
            return (command, True)
        return (self.set_command_data(command, data), True)

    def set_command_data(self, command, data) -> Command:
        if not data:
            return self.available_commands.get(command.definition.id, None)
        return Command(data, command.definition)
