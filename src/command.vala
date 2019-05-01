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
        private string _name;
        public string name {get { return _name;}}

        private string _help;
        public string help {get {return _help;}}

        private string _id;
        public string id {get {return _id;}}

        private string _data;
        public string data {get {return _data;}}

        public Command (string name, string help, string id, string data) {
            this._name = name;
            this._help = help;
            this._id = id;
            this._data = data;
        }

        /*
         * Return a copy of this with optionally changed values
         *
        */
        public Command copy (string new_name = "", string new_help = "",
                            string new_id = "", string new_data = "") {
            return new Command(new_name == "" ? new_name : this.name,
                               new_help == "" ? new_help : this.help,
                               new_id == "" ? new_id : this.id,
                               new_data == "" ? new_data : this.data);
        }

        /*
         * Return a copy of this with changed data property.
         *
        */
        public Command set_data (string new_data) {
            return new Command(this.name, this.help, this.id, new_data);
        }

        /*
         * Creates a parsers that can be used to load commands defs
        */
        public static Json.Parser[] create_parsers(string[] enabled_plugins) {
            // Load paths
            Gee.ArrayList<string> command_files = new Gee.ArrayList<string>();
            command_files.add("r:/com/orsan/Turtlico/base.json");
            command_files.add_all_array(enabled_plugins);
            // Load commands
            Gee.ArrayList<Json.Parser> parsers = new Gee.ArrayList<Json.Parser>();
            foreach(string file in command_files) {
                try {
                    var parser = new Json.Parser();
                    if (file.has_prefix("r:")) {
                        var stream = GLib.resources_open_stream(file.substring(2), GLib.ResourceLookupFlags.NONE);
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
}
