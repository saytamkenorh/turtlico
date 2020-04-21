/* scene-editor-sprite.vala
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

namespace Turtlico.SceneEditor {
    public class Sprite {
        public Gdk.Pixbuf icon;
        public string name;
        public string id;
        public int x;
        public int y;
    }
    public class Scene : Object {
        public int width {get; set;}
        public int height {get; set;}
        public ArrayList<Sprite?> sprites;

        public const string SCENE_FILE_SUFFIX = ".tcs";

        public Scene () {
            width = 1024;
            height = 768;
            sprites = new ArrayList<Sprite?>();
        }

        public Scene.from_file (File scene_file, string project_dir_path) throws Error
        {
            var parser = new Json.Parser();
            parser.load_from_file(scene_file.get_path());

            Json.Node node = parser.get_root();
            Json.Object object = node.get_object();

            width = (int)object.get_int_member("width");
            height = (int)object.get_int_member("height");
            sprites = new ArrayList<Sprite?>();

            object.get_array_member("sprites").foreach_element((array, index, node)=>{
                Sprite sprite = new Sprite();
                var sprite_obj = node.get_object();
                sprite.x = (int)sprite_obj.get_int_member("x");
                sprite.y = (int)sprite_obj.get_int_member("y");
                sprite.name = sprite_obj.get_string_member("name");
                sprite.id = sprite_obj.get_string_member("id");
                string icon_path = Path.build_path(Path.DIR_SEPARATOR_S, project_dir_path, sprite.name);
                try {
                    sprite.icon = new Gdk.Pixbuf.from_file(icon_path);
                } catch (Error e) {
                    warning("Cannot load sprite '%s': %s".printf(sprite.name, e.message));
                    return;
                }
                sprites.add(sprite);
            });
        }

        public void save (File scene_file) throws Error
        {
            var builder = new Json.Builder();
            builder.begin_object();

            builder.set_member_name("width");
            builder.add_int_value(width);

            builder.set_member_name("height");
            builder.add_int_value(height);

            builder.set_member_name("sprites");
            builder.begin_array();
            foreach (var sprite in sprites) {
                builder.begin_object();

                builder.set_member_name("x");
                builder.add_int_value(sprite.x);
                builder.set_member_name("y");
                builder.add_int_value(sprite.y);
                builder.set_member_name("name");
                builder.add_string_value(sprite.name);
                builder.set_member_name("id");
                builder.add_string_value(sprite.id);

                builder.end_object();
            }
            builder.end_array ();

            builder.end_object();

            Json.Generator generator = new Json.Generator ();
            Json.Node root = builder.get_root ();
            generator.set_root(root);
            generator.to_file(scene_file.get_path());
        }
        public static string get_basename_file(File file) {
            return get_basename(file.get_basename());
        }

        public static string get_basename(string path) {
            var name = new Gee.ArrayList<string>.wrap(Path.get_basename(path).split("."));
            if (("." + name.last()) == SCENE_FILE_SUFFIX)
                name.remove_at(name.size - 1); // Removes extension
            if (name.size > 1)
                name.remove_at(0); // Removes project name
            return string.joinv(".", name.to_array());
        }
    }
}
