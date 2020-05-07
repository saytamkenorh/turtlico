/* command.vala
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
    public class Command {
        public const string PLUGIN_RESOURCES = "/tk/turtlico/Turtlico/plugins/";

        private string _name;
        public string name {get { return _name;}}
        private Gdk.Pixbuf _pixbuf;
        public Gdk.Pixbuf pixbuf {get { return _pixbuf;}}

        private string _id;
        public string id {get {return _id;}}

        private string _data;
        public string data {get {return _data;}}

        private DrawParams _draw_params;
        public DrawParams draw_params {get {return _draw_params;}}

        private string module_dir;

        public Command (string name, string id, string data, DrawParams draw_params, string module_dir) {
            this._name = name;
            this._id = id;
            this._data = data;
            this._draw_params = draw_params;
            this.module_dir = module_dir;

            if (name.has_prefix("r:")) {
                try {
                    string str = name.substring(2);
                    this._pixbuf = new Gdk.Pixbuf.from_resource_at_scale(
                        "/tk/turtlico/Turtlico/icons/" + str,
                        (int)(50 * draw_params.scale), (int)(35 * draw_params.scale), true);
                    this._name = str;
                }
                catch {
                    this._pixbuf = null;
                }
            }
            else if (name.has_prefix("f:") && name.has_suffix(".png")) {
                try {
                    string str = name.substring(2);
                    this._pixbuf = new Gdk.Pixbuf.from_file_at_size(
                        Path.build_filename(module_dir, str),
                        (int)(50 * draw_params.scale), (int)(35 * draw_params.scale));
                    this._name = str;
                }
                catch {
                    this._pixbuf = null;
                }
            }
            else if (pixbuf != null)
                this._pixbuf = pixbuf;
            else
                this._pixbuf = null;
        }

        /*
         * Return a copy of this with changed data property.
         *
        */
        public Command set_data (string new_data, string resource_dir) {
            var c = new Command(this.name, this.id, new_data, this.draw_params, this.module_dir);
            if (this.id == "5_img") {
                if (new_data.has_suffix(".png") ||
                    new_data.has_suffix(".bmp") ||
                    new_data.has_suffix(".gif"))
                {
                    // Get Image thumbnail
                    try {
                        string path = new_data;
                        if (path.has_prefix("./")) {
                            path = Path.build_filename(resource_dir, path.substring(2));
                        }
                        var pb = new Gdk.Pixbuf.from_file_at_size(path, (int)(35 * draw_params.scale), (int)(25 * draw_params.scale));
                        c._pixbuf = pb;
                    } catch (Error e) {c._pixbuf = null; debug(e.message);}
                }
                else
                    c._pixbuf = null;
            }
            else
                c._pixbuf = pixbuf;
            return c;
        }

        /*
         * Creates a parsers that can be used to load commands defs
        */
        public static Json.Parser[] create_parsers(string[] enabled_plugins) {
            // Load paths
            Gee.ArrayList<string> command_files = new Gee.ArrayList<string>();
            command_files.add("r:base.json");
            command_files.add_all_array(enabled_plugins);
            // Load commands
            Gee.ArrayList<Json.Parser> parsers = new Gee.ArrayList<Json.Parser>();
            foreach(string file in command_files) {
                try {
                    var parser = new Json.Parser();
                    if (file.has_prefix("r:")) {
                        string path = file.substring(2);
                        path = path.replace("/tk/turtlico/Turtlico/", ""); // Backward compatibility
                        path = PLUGIN_RESOURCES + path;
                        var stream = GLib.resources_open_stream(path, GLib.ResourceLookupFlags.NONE);
                        parser.load_from_stream(stream);
                    }
                    else {
                        parser.load_from_file(file);
                    }
                    parsers.add(parser);
                }
                catch (Error e) {
                    debug(_("Failed to load command def file: ") + e.message);
                }
            }
            return parsers.to_array();
        }
    }

    public class DrawParams {
        public bool data_draw;
        public Gdk.RGBA data_color;
        public Gdk.RGBA bg_color;
        public Gdk.RGBA fg_color;
        public bool data_only;
        public float scale;

        public string help;
        public string help_en; // Used for help page opening

        public DrawParams (
            bool data_draw,
            Gdk.RGBA data_color, Gdk.RGBA bg_color, Gdk.RGBA fg_color,
            bool data_only,
            string help,
            float scale)
        {
            this.data_draw = data_draw;
            this.data_color = data_color;
            this.bg_color = bg_color;
            this.fg_color = fg_color;
            this.data_only = data_only;
            this.help = _(help);
            this.help_en = help;
            this.scale = scale;
        }
    }
}
