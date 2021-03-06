/* program-settings.vala
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

using Gee;

namespace Turtlico {
    [GtkTemplate (ui = "/io/gitlab/Turtlico/ui/program-settings.ui")]
    class ProgramSettings : Gtk.Dialog {
        [GtkChild]
        Gtk.Box plugins_box;
        [GtkChild]
        Gtk.Switch use_idle_switch;
        [GtkChild]
        Gtk.Label all_icons_count_label;
        [GtkChild]
        Gtk.Label icons_count_label;
        [GtkChild]
        Gtk.Dialog open_dir_fail_dialog;
        [GtkChild]
        Gtk.Label open_dir_fail_label;

        protected ProgramBuffer buffer;
        protected Gee.ArrayList<string> plugins_active;

        public ProgramSettings (ProgramBuffer buffer,
            ArrayList<ArrayList<Command>> program
        ) {
            use_idle_switch.set_active (buffer.run_in_console);

            this.buffer = buffer;
            this.plugins_active = buffer.enabled_plugins;
            // Add plugins
            try {
                var resources = resources_enumerate_children (Command.PLUGIN_RESOURCES,
                    ResourceLookupFlags.NONE);
                foreach (var r in resources) {
                    if (r.has_suffix (".json") && r != "base.json") {
                        string full_path = Command.PLUGIN_RESOURCES + r;
                        var json = new Json.Parser ();
                        var stream = GLib.resources_open_stream (full_path,
                            GLib.ResourceLookupFlags.NONE);
                        json.load_from_stream (stream);
                        Json.Node node = json.get_root ();
                        add_plugin (_(node.get_object ().get_string_member ("name")), "r:" + r);
                    }
                }
                foreach (var path in CommandCategory.get_file_plugin_dirs ()) {
                    if (FileUtils.test (path, FileTest.IS_DIR)) {
                        Dir dir = Dir.open (path, 0);
                        string? name = null;
                        while ((name = dir.read_name ()) != null) {
                            string file = Path.build_filename (path, name, "commands.json");
                            if (FileUtils.test (file, FileTest.IS_REGULAR)) {
                                var json = new Json.Parser ();
                                json.load_from_file (file);
                                Json.Node node = json.get_root ();
                                add_plugin (_(node.get_object ().get_string_member ("name")), file);
                            }
                        }
                    }
                }
            }
            catch (Error e) {
                var dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.OK,
                    _("Failed to load list of additional modules"));
                dialog.secondary_text = e.message;
                dialog.run ();
                dialog.destroy ();
            }
            debug ("Active plugins:");
            this.plugins_active.foreach ((s) => {debug (s); return false;});
            debug ("----------------");

            // Stats
            int icons_all = 0;
            int icons = 0;
            foreach (var line in program) {
                foreach (var c in line) {
                    icons_all++;
                    if (c.id != "nl" && c.id != "tab" && c.id != "#") {
                        icons++;
                    }
                }
            }
            all_icons_count_label.label = _("Icon count: ") + icons_all.to_string ();
            icons_count_label.label = _("Icon count without whitespace and comments: ") + icons.to_string ();
        }

        void add_plugin (string name, string file) {
            Gtk.Box plugin_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            Gtk.Label plugin_label = new Gtk.Label (name);
            plugin_box.pack_start (plugin_label);
            Gtk.Switch plugin_switch = new Gtk.Switch ();
            plugin_switch.state_set.connect ((state) => {
                if (state) {
                    if (!plugins_active.contains (file)) {
                        plugins_active.add (file);
                        buffer.program_changed = true;
                    }
                }
                else if (plugins_active.contains (file)) {
                    plugins_active.remove (file);
                    buffer.program_changed = true;
                }
                return false;
            });
            plugin_box.pack_end (plugin_switch, false, false, 0);
            plugins_box.pack_start (plugin_box, false, false, 0);
            plugin_box.show_all ();
            if (plugins_active.contains (file))
                plugin_switch.set_active (true);
        }

        [GtkCallback]
        bool on_use_idle_switch_state_set (Gtk.Switch sw, bool active) {
            if (buffer != null) {
                buffer.run_in_console = active;
                buffer.program_changed = true;
            }
            return false;
        }

        [GtkCallback]
        void on_open_dir_clicked () {
            string dir = Path.build_filename (Environment.get_user_data_dir (), "turtlico", "plugins");
            try {
                if (!FileUtils.test (dir, FileTest.IS_DIR)) {
                    File file = File.new_for_path (dir);
                    file.make_directory_with_parents ();
                }
            } catch (Error e) {
                warning ("Cannot create user plugins folder: " + e.message);
            }
            try {
                Gtk.show_uri_on_window (this, "file://" + dir, Gdk.CURRENT_TIME);
            } catch (Error e) {
                open_dir_fail_label.label = dir;
                open_dir_fail_dialog.transient_for = this;
                open_dir_fail_dialog.run (); open_dir_fail_dialog.hide ();
            }
        }
    }
}
