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
	[GtkTemplate (ui = "/com/orsan/Turtlico/app-settings.ui")]
	class AppSettings : Gtk.Window {
        [GtkChild]
        Gtk.AboutDialog about_dialog;
        [GtkChild]
        Gtk.Switch dark_mode_switch;

        Settings settings = new Settings("com.orsan.Turtlico");

        public AppSettings () {
           about_dialog.set_transient_for(this);
           about_dialog.set_logo(null);
           about_dialog.version = TURTLICO_VERSION;

           dark_mode_switch.active = settings.get_boolean("dark-mode");
        }

        [GtkCallback]
        void on_about_btn_clicked () {
            about_dialog.run();
            about_dialog.hide();
        }

        [GtkCallback]
        bool on_dark_mode_switch_state_set(Gtk.Switch sw, bool state) {
            settings.set_boolean("dark-mode", state);
            return false;
        }
	}
}
