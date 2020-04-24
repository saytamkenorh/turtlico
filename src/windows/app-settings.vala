/* window.vala
 *
 * Copyright 2019 matyas5
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
 */

extern const string TURTLICO_VERSION;

namespace Turtlico {
	[GtkTemplate (ui = "/tk/turtlico/Turtlico/windows/app-settings.ui")]
	class AppSettings : Gtk.Window {
        [GtkChild]
        Gtk.Switch dark_mode_switch;
        [GtkChild]
        Gtk.Switch dark_icons_switch;
        [GtkChild]
        Gtk.Switch debug_data_switch;
        [GtkChild]
        Gtk.Switch auto_indent_switch;
        #if LINUX
        [GtkChild]
        Gtk.Switch csd_switch;
        [GtkChild]
        Gtk.Label csd_label;
        #endif

        Settings settings = new Settings("tk.turtlico.Turtlico");

        public AppSettings () {
            dark_mode_switch.active = settings.get_boolean("dark-mode");
            dark_icons_switch.active = settings.get_boolean("dark-icons");
            debug_data_switch.active = settings.get_boolean("debug-data");
            auto_indent_switch.active = settings.get_boolean("auto-indent");
            #if LINUX
            csd_switch.active = settings.get_boolean("csd");
            csd_switch.visible = true;
            csd_label.visible = true;
            #endif
        }

        [GtkCallback]
        bool on_dark_mode_switch_state_set(Gtk.Switch sw, bool state) {
            settings.set_boolean("dark-mode", state);
            return false;
        }

        [GtkCallback]
        bool on_dark_icons_switch_state_set(Gtk.Switch sw, bool state) {
            settings.set_boolean("dark-icons", state);
            return false;
        }

        [GtkCallback]
        bool on_debug_data_switch_state_set(Gtk.Switch sw, bool state) {
            settings.set_boolean("debug-data", state);
            return false;
        }
        [GtkCallback]
        bool on_auto_indent_switch_state_set(Gtk.Switch sw, bool state) {
            settings.set_boolean("auto-indent", state);
            return false;
        }
        [GtkCallback]
        bool on_csd_switch_state_set(Gtk.Switch sw, bool state) {
            settings.set_boolean("csd", state);
            return false;
        }
	}
}
