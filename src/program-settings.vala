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

namespace Turtlico {
	[GtkTemplate (ui = "/com/orsan/Turtlico/program-settings.ui")]
	class ProgramSettings : Gtk.Window {
	    [GtkChild]
	    Gtk.Box plugins_box;

	    public Gee.ArrayList<string> plugins_active;

	    public ProgramSettings (ref Gee.ArrayList<string> plugins_active) {
            this.plugins_active = plugins_active;
            // Add plugins
            try {
                var resources = resources_enumerate_children("/com/orsan/Turtlico",
                    ResourceLookupFlags.NONE);
                foreach(var r in resources)
                {
                    if(r.has_suffix(".json") && r !="base.json") {
                        string full_path = "/com/orsan/Turtlico/" + r;
                        var json = new Json.Parser();
                        var stream = GLib.resources_open_stream(full_path,
                            GLib.ResourceLookupFlags.NONE);
                        json.load_from_stream(stream);
                        Json.Node node = json.get_root ();
                        add_plugin(_(node.get_object().get_string_member("name")), "r:" + full_path);
                    }
                }
            }
            catch (Error e) {
                var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.OK,
                    _("Failed to load list of addinitional modules"));
                dialog.run();
                dialog.destroy();
            }
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
	}
}
