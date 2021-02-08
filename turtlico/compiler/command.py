# command.py
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
import os
import importlib.util
import inspect
from collections import namedtuple
from enum import Enum
from typing import Union, Dict, Tuple

from gi.repository import GObject, Gio, Gdk, GLib

from turtlico.compiler.utils import error, SVGFileTexture
import turtlico.compiler.codepiece as codepiece

PLUGIN_RESOURCES = '/io/gitlab/Turtlico/plugins'
IMAGE_EXTENSIONS = ['.png', '.bmp', '.gif']

CommandIcon = Union[SVGFileTexture, str]
Command = namedtuple('Command', ['data', 'definition'])
CommandModule = namedtuple('CommandModule', ['deps', 'code'])
CommandEvent = namedtuple(
    'CommandEvent', ['name', 'handler', 'connector', 'params'])


class CommandType(Enum):
    INTERNAL = 0
    METHOD = 1
    OPERATOR = 2
    # Keyword with one parameter
    KEYWORD = 3
    # No additional logic
    CODE_SNIPPET = 4
    # Keyword with multiple parameters (parameters ends with :)
    KEYWORD_WITH_ARGS = 5


class CommandColor(Enum):
    DEFAULT = 0
    INDENTATION = 1
    COMMENT = 2
    CYCLE = 3
    KEYWORD = 4
    NUMBER = 5
    STRING = 6
    OBJECT = 7


CommandColorScheme = Dict[CommandColor, Tuple[Gdk.RGBA, Gdk.RGBA]]


class CommandDefinition(GObject.Object):
    id: str
    icon: CommandIcon
    help: str
    color: CommandColor
    has_data: bool
    data_only: bool
    command_type: CommandType
    function: str
    default_params: Union[str, None]
    snippet: Union[codepiece.TcpPiece, None]

    def __init__(self,
                 id: str, icon: CommandIcon, help: str,
                 command_type: CommandType, function: str = None,
                 default_params: str = None,
                 has_data: bool = False, data_only: bool = False,
                 color: CommandColor = CommandColor.DEFAULT,
                 snippet: str = None):
        super().__init__()
        self.id = id
        self.icon = icon
        self.help = help

        self.command_type = command_type
        self.function = function
        self.default_params = default_params

        self.has_data = has_data
        self.data_only = data_only
        self.color = color
        self.snippet = codepiece.parse_tcp(snippet) if snippet else None

    def __str__(self):
        return self.id

    def __repr__(self):
        return f'CommandDefinition(id="{self.id}")'


class CommandCategory(GObject.Object):
    plugin: Plugin
    icon: CommandIcon
    command_definitions: Gio.ListStore

    def __init__(self, plugin: Plugin, icon: CommandIcon,
                 command_definitions: list[CommandDefinition]):
        super().__init__()
        assert type(plugin) is Plugin
        assert isinstance(icon, CommandIcon.__args__)
        assert isinstance(command_definitions, list)

        self.plugin = plugin
        self.icon = icon
        self.command_definitions = Gio.ListStore.new(CommandDefinition)
        self.command_definitions.splice(0, 0, command_definitions)


class Plugin():
    id: str
    name: str
    list_priority: int
    categories: list[CommandCategory]
    modules: dict[str, CommandModule]
    events: list[CommandEvent]

    def __init__(self, name: str, list_priority: int = 0):
        assert isinstance(name, str)
        assert isinstance(list_priority, int)

        self.name = name
        self.list_priority = list_priority

        self.categories = []
        self.modules = {}
        self.events = []

    @staticmethod
    def new_from_path(path: str) -> Plugin:
        """path: Path to a Python module"""
        name = Plugin.get_id_from_path(path)
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        plugin = module.get_plugin()

        assert type(plugin) is Plugin

        plugin.id = name
        return plugin

    @staticmethod
    def get_all(load_content=True) -> dict[str, Plugin]:
        paths = Plugin.get_paths()
        return Plugin.get_from_paths(paths)

    @staticmethod
    def get_paths() -> list[str]:
        """
        Returns paths of all available plugins
        Path is a path to a Python module
        """
        paths = []
        file_plugin_dirs = [
            *GLib.get_system_data_dirs(),
            GLib.get_user_data_dir(),
            "/run/host/usr/share"
        ]
        for d in file_plugin_dirs:
            path = os.path.join(d, 'turtlico/turtlico/plugins')
            if not os.path.isdir(path):
                continue
            with os.scandir(path) as it:
                for entry in it:
                    if (
                            (not entry.is_file())
                            or (not entry.name.endswith('.py'))):
                        continue
                    paths.append(entry.path)
        return paths

    @staticmethod
    def get_from_paths(
            plugin_paths: list[str]) -> dict[str, Plugin]:
        """
        plugin_paths: Paths to Python modules
        """
        plugin_paths = set(plugin_paths)
        plugins = {}  # Output

        for path in plugin_paths:
            id = Plugin.get_id_from_path(path)
            try:
                plugins[id] = Plugin.new_from_path(path)
            except Exception as e:
                error(f'Cannot load plugin "{id}": {e}')
        return plugins

    @staticmethod
    def get_id_from_path(path: str) -> str:
        """
        Returns id as a string
        """
        return os.path.splitext(os.path.basename(path))[0]


def icon(icon: str) -> CommandIcon:
    """
    Loads CommandIcon from file
    """
    plugin_dir = os.path.dirname(inspect.stack()[1].filename)
    path = os.path.join(plugin_dir, 'icons', icon)
    return SVGFileTexture(path)
