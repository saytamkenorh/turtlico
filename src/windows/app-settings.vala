/* app-settings.vala
 *
 * Copyright 2020 matyas5
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */



extern const string TURTLICO_VERSION;

namespace Turtlico {
    [GtkTemplate (ui = "/io/gitlab/Turtlico/ui/app-settings.ui")]
    class AppSettings : Gtk.Window {
        [GtkChild]
        Gtk.Switch dark_mode_switch;
        [GtkChild]
        Gtk.Switch dark_icons_switch;
        [GtkChild]
        Gtk.Switch debug_data_switch;
        [GtkChild]
        Gtk.Switch auto_indent_switch;
        [GtkChild]
        Gtk.Switch code_preview_switch;
        #if LINUX
        [GtkChild]
        Gtk.Switch csd_switch;
        [GtkChild]
        Gtk.Label csd_label;
        #endif

        Settings settings = new Settings ("io.gitlab.Turtlico");

        public AppSettings () {
            settings.bind("dark-mode", dark_mode_switch, "state", SettingsBindFlags.DEFAULT);
            settings.bind("dark-icons", dark_icons_switch, "state", SettingsBindFlags.DEFAULT);
            settings.bind("debug-data", debug_data_switch, "state", SettingsBindFlags.DEFAULT);
            settings.bind("auto-indent", auto_indent_switch, "state", SettingsBindFlags.DEFAULT);
            settings.bind("code-preview", code_preview_switch, "state", SettingsBindFlags.DEFAULT);
            #if LINUX
            settings.bind("csd", csd_switch, "state", SettingsBindFlags.DEFAULT);
            csd_switch.visible = true;
            csd_label.visible = true;
            #endif
        }
    }
}
