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
    public const string TURTLICO_RESOURCES = "/io/gitlab/Turtlico/";

    public class Command : Object {
        public const string PLUGIN_RESOURCES = TURTLICO_RESOURCES + "plugins/";

        public string id {get {return definition.id;}}
        public string icon_path {get {return definition.icon_path;}}

        // Data that are unique to a single instance of a command
        private string _data;
        public string data {get {return _data;}}
        public Gdk.Pixbuf? pixbuf {
            get {
                if (_data_pixbuf != null)
                    return _data_pixbuf;
                else
                    return definition.pixbuf;
            }
        }
        // Preview of data (i e. image file that is represented by the icon)
        private Gdk.Pixbuf _data_pixbuf = null;
        public Gdk.Pixbuf data_pixbuf {get {return _data_pixbuf;}}

        private CommandDefinition _definition;
        public CommandDefinition definition {get {return _definition;}}

        public Command (CommandDefinition definition, string data) {
            this._data = data;
            this._definition = definition;
            set_data_to (this, data, null);
        }

        /*
         * Return a copy of this with changed data property.
         *
         * new_data: The new data to set.
         * resource_dir: Directory of the opened program (used for previews of 5_img).
        */
        public Command copy (string new_data, string resource_dir) {
            var c = new Command (this.definition, new_data);
            set_data_to (c, new_data, resource_dir);
            return c;
        }

        private static void set_data_to (Command c, string new_data, string? resource_dir) {
            if (c.id == "5_img" && resource_dir != null) {
                if (new_data.has_suffix (".png") ||
                    new_data.has_suffix (".bmp") ||
                    new_data.has_suffix (".gif")) {
                    // Get Image thumbnail
                    try {
                        string path = new_data;
                        if (path.has_prefix ("./")) {
                            path = Path.build_filename (
                                resource_dir, path.substring (2));
                        }
                        var pb = new Gdk.Pixbuf.from_file_at_size (path,
                            (int)(35 * c.definition.scale), (int)(25 * c.definition.scale));
                        c._data_pixbuf = pb;
                    } catch (Error e) {c._data_pixbuf = null; debug (e.message);}
                }
                else
                    c._data_pixbuf = null;
            }
            else
                c._data_pixbuf = null;
        }

        public static Gdk.Pixbuf? get_pixbuf_from_icon_path (string icon, float scale_factor, string plugin_dir) {
            Gdk.Pixbuf pixbuf = null;
            try {
                if (icon.has_prefix ("r:")) {
                    pixbuf = new Gdk.Pixbuf.from_resource_at_scale (
                        TURTLICO_RESOURCES + "icons/" + icon.substring (2),
                        (int)(50 * scale_factor), (int)(35 * scale_factor), true);
                }
                else if (icon.has_prefix ("f:")) {
                    pixbuf = new Gdk.Pixbuf.from_file_at_size (
                        Path.build_filename (plugin_dir, icon.substring (2)),
                        (int)(35 * scale_factor), (int)(50 * scale_factor));
                }
                else {
                    return null;
                }
            } catch {}
            return pixbuf;
        }
    }

    public class CommandCategory : Object {
        public string icon_path;
        public Gdk.Pixbuf icon;
        public Command[] commands;

        public static string[] get_file_plugin_dirs () {
            var plugins_search_dirs = new Gee.ArrayList<string>.wrap (Environment.get_system_data_dirs ());
            plugins_search_dirs.add (Environment.get_user_data_dir ());
#if TURTLICO_FLATPAK
            plugins_search_dirs.add ("/run/host/usr/share");
#endif
            for (int i = 0; i < plugins_search_dirs.size; i++) {
                plugins_search_dirs[i] = Path.build_filename (plugins_search_dirs[i], "/turtlico/plugins");
            }
            return plugins_search_dirs.to_array ();
        }

        /*
         * Creates a parsers that can be used to load commands defs
        */
        public static Json.Parser[] create_parsers (string[] enabled_plugins) throws FileError {
            // Load commands
            Gee.ArrayList<Json.Parser> parsers = new Gee.ArrayList<Json.Parser> ();
            foreach (string file in enabled_plugins) {
                try {
                    var parser = new Json.Parser ();
                    if (file.has_prefix ("r:")) {
                        string path = file.substring (2);
                        path = path.replace ("/io/gitlab/Turtlico/", ""); // Backward compatibility
                        path = Command.PLUGIN_RESOURCES + path;
                        var stream = GLib.resources_open_stream (path, GLib.ResourceLookupFlags.NONE);
                        parser.load_from_stream (stream);
                    }
                    else {
                        parser.load_from_file (file);
                    }
                    parsers.add (parser);
                }
                catch (Error e) {
                    throw new FileError.ACCES (_("Failed to load command def file: ") + e.message);
                }
            }
            return parsers.to_array ();
        }

        public static CommandCategory[] get_command_categories (
            string[] plugins,
            int icon_scale
        ) throws FileError {
            var output_categories = new Gee.ArrayList<CommandCategory> ();
            var parsers = create_parsers (plugins);
            var default_fg_color = "rgb(255, 255, 255)";

            int i = 0;
            foreach (Json.Parser parser in parsers) {
                // Get module dir
                string plugin_dir = "";
                if (!plugins[i].has_prefix ("r:")) {
                    plugin_dir = Path.get_dirname (plugins[i]);
                }
                i++;

                // Get the root node:
                Json.Node node = parser.get_root ();
                // For all commands in all categories
                var categories = node.get_object ().get_array_member ("categories");
                categories.foreach_element ((array, index_, category_node) => {
                    var output_category = new CommandCategory ();
                    output_category.icon_path = category_node.get_object ().get_string_member ("icon");
                    output_category.icon = Command.get_pixbuf_from_icon_path (
                        output_category.icon_path,
                        0.5f, plugin_dir);

                    // Add commands to
                    var output_category_commands = new Gee.ArrayList<Command> ();
                    var commands = category_node.get_object ().get_array_member ("commands");
                    commands.foreach_element ((array, index_, command_node) => {
                        // Parse one command
                        Json.Object command = command_node.get_object ();

                        bool draw_data = command.has_member ("data-draw") ?
                            command.get_boolean_member ("data-draw") : false;

                        Gdk.RGBA data_color = Gdk.RGBA ();
                        data_color.parse (command.has_member ("data-color") ?
                            command.get_string_member ("data-color") : "#ffffff");

                        Gdk.RGBA? bg_color = null;
                        if (command.has_member ("bg-color")) {
                            bg_color = Gdk.RGBA ();
                            bg_color.parse (command.get_string_member ("bg-color"));
                        }

                        Gdk.RGBA fg_color = Gdk.RGBA ();
                        fg_color.parse (command.has_member ("fg-color") ?
                            command.get_string_member ("fg-color") : default_fg_color);

                        bool data_only = command.has_member ("data-only") ?
                            command.get_boolean_member ("data-only") : true;

                        string snippet = null;
                        if (command.has_member ("snippet")) snippet = command.get_string_member ("snippet");

                        var command_definition = new CommandDefinition (
                            command.get_string_member ("id"),
                            command.get_string_member ("icon"),
                            draw_data, data_color, bg_color, fg_color, data_only,
                            command.get_string_member ("?"),
                            snippet,
                            icon_scale, plugin_dir);
                        Command c = new Command (command_definition, "");
                        output_category_commands.add (c);
                    });
                    output_category.commands = output_category_commands.to_array ();
                    output_categories.add (output_category);
                });
            }
            return output_categories.to_array ();
        }
    }

    // Contains all data about an icon except of things
    // that are specific to a single instance of an icon (data, preview).
    public class CommandDefinition {
        public string id;
        public string icon_path;
        public Gdk.Pixbuf pixbuf;

        public bool data_draw;
        public Gdk.RGBA data_color;
        public Gdk.RGBA? bg_color;
        public Gdk.RGBA fg_color;
        public bool data_only;
        public float scale;

        public string help;
        public string help_en; // Used for help page opening
        public string snippet;

        public CommandDefinition (
            string id,
            string icon_path,
            bool data_draw,
            Gdk.RGBA data_color, Gdk.RGBA? bg_color, Gdk.RGBA fg_color,
            bool data_only,
            string help, string? snippet,
            float scale,
            string plugin_dir
        ) {
            this.id = id;
            this.icon_path = icon_path;
            this.pixbuf = Command.get_pixbuf_from_icon_path (this.icon_path, (int)scale, plugin_dir);
            this.data_draw = data_draw;
            this.data_color = data_color;
            this.bg_color = bg_color;
            this.fg_color = fg_color;
            this.data_only = data_only;
            this.help = _(help);
            this.help_en = help;
            this.snippet = snippet;
            this.scale = scale;
        }
    }
}
