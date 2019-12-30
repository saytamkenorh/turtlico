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

using Gee;

namespace Turtlico {
	[GtkTemplate (ui = "/tk/turtlico/Turtlico/program-settings.ui")]
	class ProgramSettings : Gtk.Window {
	    [GtkChild]
	    Gtk.Box plugins_box;
	    [GtkChild]
	    Gtk.Label all_icons_count_label;
	    [GtkChild]
	    Gtk.Label icons_count_label;
	    [GtkChild]
	    Gtk.Dialog open_dir_fail_dialog;
        [GtkChild]
	    Gtk.Label open_dir_fail_label;

	    public Gee.ArrayList<string> plugins_active;

	    public ProgramSettings (ref Gee.ArrayList<string> plugins_active,
	        ArrayList<ArrayList<Command>> program) {
            this.plugins_active = plugins_active;
            // Add plugins
            try {
                var resources = resources_enumerate_children("/tk/turtlico/Turtlico",
                    ResourceLookupFlags.NONE);
                foreach(var r in resources)
                {
                    if(r.has_suffix(".json") && r !="base.json") {
                        string full_path = "/tk/turtlico/Turtlico/" + r;
                        var json = new Json.Parser();
                        var stream = GLib.resources_open_stream(full_path,
                            GLib.ResourceLookupFlags.NONE);
                        json.load_from_stream(stream);
                        Json.Node node = json.get_root ();
                        add_plugin(_(node.get_object().get_string_member("name")), "r:" + full_path);
                    }
                }
                var plugins_search_dirs = new Gee.ArrayList<string>.wrap(Environment.get_system_data_dirs());
                plugins_search_dirs.add(Environment.get_user_data_dir());
                foreach (var path in plugins_search_dirs) {
                    path = path + "/turtlico/plugins";
                    if (FileUtils.test(path, FileTest.IS_DIR)) {
                        Dir dir = Dir.open (path, 0);
		                string? name = null;
		                while ((name = dir.read_name ()) != null) {
			                string file = Path.build_filename (path, name, "commands.json");
			                if (FileUtils.test (file, FileTest.IS_REGULAR)) {
                                var json = new Json.Parser();
                                json.load_from_file(file);
                                Json.Node node = json.get_root ();
                                add_plugin(_(node.get_object().get_string_member("name")), file);
			                }
		                }
                    }
                }
            }
            catch (Error e) {
                var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.OK,
                    _("Failed to load list of additional modules"));
                dialog.secondary_text = e.message;
                dialog.run();
                dialog.destroy();
            }
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
            all_icons_count_label.label = _("Icon count: ") + icons_all.to_string();
            icons_count_label.label = _("Icon count without whitespace and comments: ") + icons.to_string();
	    }

	    void add_plugin(string name, string file) {
            Gtk.Box plugin_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Gtk.Label plugin_label = new Gtk.Label(name);
            plugin_box.pack_start(plugin_label);
            Gtk.Switch plugin_switch = new Gtk.Switch();
            plugin_switch.state_set.connect((state)=>{
                if (state) {
                    if (!plugins_active.contains(file))
                        plugins_active.add(file);
                }
                else
                    plugins_active.remove(file);
                return false;
            });
            plugin_box.pack_end(plugin_switch, false, false, 0);
            plugins_box.pack_start(plugin_box, false, false, 0);
            this.plugins_active.foreach((s)=>{debug(s); return false;});
            if (plugins_active.contains(file))
                plugin_switch.set_active(true);

	    }

	    [GtkCallback]
	    void on_open_dir_clicked() {
            string dir = Path.build_filename(Environment.get_user_data_dir(), "turtlico", "plugins");
            try {
                Gtk.show_uri_on_window(this, "file://" + dir, Gdk.CURRENT_TIME);
            }
            catch(Error e) {
                open_dir_fail_label.label = dir;
                open_dir_fail_dialog.transient_for = this;
                open_dir_fail_dialog.run(); open_dir_fail_dialog.hide();
            }
	    }
	}
}
