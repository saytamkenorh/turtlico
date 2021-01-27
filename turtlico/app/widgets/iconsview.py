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

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import GObject, GLib, Gio, Gtk, Gdk

import turtlico.compiler as compiler
from turtlico.compiler.projectbuffer import ProjectBuffer
import turtlico.app.widgets as widgets


@Gtk.Template(resource_path='/io/gitlab/Turtlico/ui/iconsview.ui')
class IconsView(Gtk.Box):
    __gtype_name__ = 'TurtlicoIconsView'

    _categories_list_box = Gtk.Template.Child()
    _grid_view: Gtk.GridView = Gtk.Template.Child()

    _categories: Gio.ListStore
    _colors: compiler.CommandColorScheme
    _grid_view_factory: Gtk.SignalListItemFactory
    _project_buffer_available_commands_changed_id: int
    _project_buffer: ProjectBuffer

    @GObject.Property(type=ProjectBuffer)
    def project_buffer(self):
        return self._project_buffer

    @project_buffer.setter
    def project_buffer(self, value):
        if self._project_buffer:
            self._project_buffer.disconnect(
                self._project_buffer_available_commands_changed_id)
        self._project_buffer = value
        self._project_buffer_available_commands_changed_id = (
            self._project_buffer.connect(
                'available-commands-changed', self._reload))
        self._reload()

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._project_buffer = None
        self._colors = None

        self._grid_view_factory = Gtk.SignalListItemFactory.new()
        self._grid_view_factory.connect('bind', self._command_bind)
        self._grid_view_factory.connect('setup', self._command_setup)
        self._grid_view_factory.connect('teardown', self._command_teardown)
        self._grid_view_factory.connect('unbind', self._command_unbind)
        self._grid_view.props.factory = self._grid_view_factory

        self._categories = Gio.ListStore.new(compiler.CommandCategory)
        self._categories_list_box.bind_model(self._categories,
                                             self._create_category_widget)

    def set_colors(self, colors: compiler.CommandColorScheme):
        self._colors = colors

    @Gtk.Template.Callback()
    def on_categories_list_box_row_selected(self, box, row: Gtk.ListBoxRow):
        category = self._categories[row.get_index()]
        self._grid_view.set_model(
            Gtk.NoSelection.new(category.command_definitions))

    def _reload(self, *args):
        if not self._colors:
            raise Exception('Please call set_colors before using this widget')
        self._categories.remove_all()
        for p in self._project_buffer.enabled_plugins.values():
            for c in p.categories:
                self._categories.append(c)
        self._categories.sort(self._category_widget_sorter)
        row = self._categories_list_box.get_row_at_index(0)
        if row:
            self._categories_list_box.select_row(row)

    def _create_category_widget(self,
                                item: compiler.CommandCategory
                                ) -> Gtk.Widget:
        if isinstance(item.icon, str):
            widget = Gtk.Label.new(item.icon)
        else:
            widget = Gtk.Image.new()
            widget.props.pixel_size = 16
            widget.props.paintable = item.icon
        return widget

    def _category_widget_sorter(self,
                                a: compiler.CommandCategory,
                                b: compiler.CommandCategory):
        lpa = a.plugin.list_priority
        lpb = b.plugin.list_priority
        if lpa != lpb:
            return -1 if lpa > lpb else 1
        return 0

    def _command_bind(self, factory, item: Gtk.ListItem):
        defin: compiler.CommandDefinition = item.props.item
        cmd = compiler.Command(None, defin)
        item.props.child.set_command(cmd)

    def _command_setup(self, factory, item: Gtk.ListItem):
        widget = widgets.SingleIconWidget(self._colors)
        item.props.child = widget

    def _command_teardown(self, factory, item: Gtk.ListItem):
        pass

    def _command_unbind(self, factory, item: Gtk.ListItem):
        item.props.child.set_command(None)


GObject.type_register(IconsView)
