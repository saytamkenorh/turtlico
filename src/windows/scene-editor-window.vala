/* scene-editor.vala
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
using Turtlico.SceneEditor;

namespace Turtlico.SceneEditor {
    enum ScenesViewCols {
        NAME
    }
    enum SpritesViewCols {
        ICON,
        NAME
    }

    [GtkTemplate (ui = "/io/gitlab/Turtlico/windows/scene-editor-window.ui")]
    public class Window : Gtk.Window {
        [GtkChild]
        Gtk.ListStore scenes_store;
        [GtkChild]
        Gtk.TreeView scenes_view;
        [GtkChild]
        Gtk.ListStore sprites_store;
        [GtkChild]
        Gtk.IconView sprites_view;
        [GtkChild]
        Gtk.Entry add_scene_entry;
        [GtkChild]
        Gtk.Entry scene_name_entry;
        [GtkChild]
        Gtk.Button save_btn;
        [GtkChild]
        Gtk.Button delete_btn;
        [GtkChild]
        Gtk.ScrolledWindow scene_view_sw;
        // Properties
        [GtkChild]
        Gtk.Entry selected_sprite;
        [GtkChild]
        Gtk.SpinButton prop_x;
        [GtkChild]
        Gtk.SpinButton prop_y;
        [GtkChild]
        Gtk.SpinButton prop_w;
        [GtkChild]
        Gtk.SpinButton prop_h;
        [GtkChild]
        Gtk.Button sprite_move_down_btn;
        [GtkChild]
        Gtk.Button sprite_move_up_btn;
        [GtkChild]
        Gtk.Button remove_sprite_btn;

        SceneEditor.View scene_view;
        ProgramView programview;

        protected string scene_prefix; // Path prefix for scene files. Eg "/home/user/project/projectname."
        protected string project_dir_path;
        protected string project_name;
        static string[] supported_image_exts = {".gif", ".png", ".bmp"};
        const int SPRITES_PREVIEW_SIZE = 32;

        FileMonitor resource_monitor;
        // Current scene data
        File scene_file {get; set;}
        Scene scene;
        private bool _scene_changed = false;
        bool scene_changed {
            get {return _scene_changed;}
            set {_scene_changed=value; update_window_title ();}
        }

        public Window (File project_file, ProgramView programview) {
            this.programview = programview;
            // Scene file
            notify["scene-file"].connect (update_window_title);
            scene_file = null;
            scene_changed = false;
            scenes_store.set_sort_column_id (ScenesViewCols.NAME, Gtk.SortType.ASCENDING);
            sprites_store.set_sort_column_id (SpritesViewCols.NAME, Gtk.SortType.ASCENDING);

            init_scene_view ();

            string basename = project_file.get_basename ();
            project_dir_path = Path.get_dirname (project_file.get_path ());
            if (basename.has_suffix (".tcp")) {
                basename = basename.splice (-4, basename.length);
            }
            project_name = basename;
            this.scene_prefix = Path.build_path (
                Path.DIR_SEPARATOR_S,
                project_dir_path,
                basename + ".");

            // Sprites widgets
            sprites_view.set_text_column (SpritesViewCols.NAME);
            sprites_view.set_pixbuf_column (SpritesViewCols.ICON);

            // Setup directory monitor
            File project_dir = File.new_for_path (project_dir_path);
            try {
                resource_monitor = project_dir.monitor (FileMonitorFlags.NONE, null);
                resource_monitor.changed.connect (on_resource_monitor_change);
            } catch (Error e) {
                warning ("Unable to setup monitor in project dir.");
            }
            reload_resources ();
            init_sprites_view ();
            update_window_title ();
            unload_scene (); // Set UI to "No scene opened" state
        }

        void init_sprites_view () {
            Gtk.drag_source_set (
                sprites_view,
                Gdk.ModifierType.BUTTON1_MASK,
                DND_TARGET_LIST, // Defined in program view
                Gdk.DragAction.COPY);
        }

        void init_scene_view () {
            // Scene view
            scene_view = new SceneEditor.View (programview);
            scene_view_sw.add (scene_view);
            scene_view.selection_changed.connect (on_scene_view_selection_changed);
            scene_view.selection_moved.connect (() => {
                if (scene_view.selected_sprite == null) return;
                prop_x.set_value (scene_view.selected_sprite.x);
                prop_y.set_value (scene_view.selected_sprite.y);
            });
            scene_view.scene_changed.connect (() => {scene_changed=true;});
            scene_view.show_all ();
        }

        void update_window_title () {
            string title = _("Scene editor") + " (" + project_name;
            if (scene_view.scene != null) {
                title += "/";
                title += Scene.get_basename_file (scene_file);
                if (scene_changed) title+="*";
            }
            title += ")";
            set_title (title);
        }

        void on_resource_monitor_change (File file, File? other_file, FileMonitorEvent event_type) {
            reload_resources ();
        }

        [GtkCallback]
        void on_add_scene_btn_clicked () {
            if (check_file_save ()) return;
            scene = new Scene ();
            scene_file = File.new_for_path (
                scene_prefix + add_scene_entry.get_text () + Scene.SCENE_FILE_SUFFIX);
            save ();
            load ();
            add_scene_entry.set_text ("");

        }

        [GtkCallback]
        void on_save_btn_clicked () {
            scene_file = File.new_for_path (
                scene_prefix + scene_name_entry.get_text () + Scene.SCENE_FILE_SUFFIX);
            save ();
        }

        [GtkCallback]
        void on_delete_btn_clicked () {
            if (scene_file == null) return;
            // Confirmation dialog
            var dialog = new Gtk.MessageDialog (this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                _("Do you really wish to delete the scene?"));
            dialog.secondary_text = _("This cannot be undone.");
            var result = dialog.run (); dialog.destroy ();
            if (result == Gtk.ResponseType.NO) return;

            try {
                scene_file.delete ();
                unload_scene ();
            } catch (Error e) {
                msg (_("Cannot delete the scene"), e.message, Gtk.MessageType.ERROR);
            }
        }

        [GtkCallback]
        void on_scenes_view_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            if (check_file_save ()) return;
            string name;
            Gtk.TreeIter iter;
            scenes_store.get_iter (out iter, path);
            scenes_store.get (iter, ScenesViewCols.NAME, out name, -1);
            scene_file = File.new_for_path (
                scene_prefix + name + Scene.SCENE_FILE_SUFFIX);
            load ();
        }

        [GtkCallback]
        bool on_scenes_view_button_press_event (Gdk.EventButton event) {
            if (event.button == Gdk.BUTTON_SECONDARY) {
                var selection = scenes_view.get_selection ();
                string scene;
                Gtk.TreeIter iter;
                if (!selection.get_selected (null, out iter)) return false;
                scenes_store.get (iter, ScenesViewCols.NAME, out scene, -1);

                programview.paste_data (
                        @"0_scene;~str;$(scene)~".replace ("~", ProgramBuffer.str_mark_utf8));
                var toplevel = programview.get_toplevel ();
                if (toplevel is Gtk.Window)
                    ((Gtk.Window)toplevel).present ();
            }
            return false;
        }

        [GtkCallback]
        bool on_sprites_view_button_press_event (Gdk.EventButton event) {
            if (event.button == Gdk.BUTTON_SECONDARY) {
                var path = sprites_view.get_path_at_pos ((int)event.x, (int)event.y);
                if (path == null) return false;
                string sprite;
                Gtk.TreeIter iter;
                if (!sprites_store.get_iter (out iter, path)) return false;
                sprites_store.get (iter, SpritesViewCols.NAME, out sprite, -1);

                programview.paste_data (
                        @"5_img;./$(sprite)~".replace ("~", ProgramBuffer.str_mark_utf8));
                var toplevel = programview.get_toplevel ();
                if (toplevel is Gtk.Window)
                    ((Gtk.Window)toplevel).present ();
            }
            return false;
        }

        [GtkCallback]
        void on_sprites_view_drag_begin (Gdk.DragContext context) {
            if (sprites_view.get_selected_items ().length () == 0)
                return;
            var selected_path = sprites_view.get_selected_items ().nth_data (0);
            Gtk.TreeIter selected_iter;
            sprites_view.get_model ().get_iter (out selected_iter, selected_path);
            Gdk.Pixbuf pixbuf;
            sprites_view.get_model ().get (selected_iter, SpritesViewCols.ICON, out pixbuf);
            Gtk.drag_set_icon_pixbuf (context, pixbuf, SPRITES_PREVIEW_SIZE / 2, SPRITES_PREVIEW_SIZE / 2);
        }

        [GtkCallback]
        void on_sprites_view_drag_data_get (Gdk.DragContext context,
            Gtk.SelectionData selection_data, uint info, uint time_
        ) {
            if (sprites_view.get_selected_items ().length () == 0)
                return;
            var selected_path = sprites_view.get_selected_items ().nth_data (0);
            Gtk.TreeIter selected_iter;
            sprites_view.get_model ().get_iter (out selected_iter, selected_path);
            string name;
            sprites_view.get_model ().get (selected_iter, SpritesViewCols.NAME, out name);
            selection_data.set_text (name, -1);
        }

        [GtkCallback]
        void on_sprites_view_drag_end (Gdk.DragContext context) {
            sprites_view.unselect_all ();
        }

        [GtkCallback]
        void on_prop_x_value_changed () {
            if (scene_view.selected_sprite == null) return;
            scene_view.set_sprite_x (scene_view.selected_sprite,
                prop_x.get_value_as_int ());
        }
        [GtkCallback]
        void on_prop_y_value_changed () {
            if (scene_view.selected_sprite == null) return;
            scene_view.set_sprite_y (scene_view.selected_sprite,
                prop_y.get_value_as_int ());
        }
        [GtkCallback]
        void on_prop_w_value_changed () {
            if (scene == null || !prop_w.get_editable ()) return;
            scene_view.set_scene_width (prop_w.get_value_as_int ());
        }
        [GtkCallback]
        void on_prop_h_value_changed () {
            if (scene == null || !prop_h.get_editable ()) return;
            scene_view.set_scene_height (prop_h.get_value_as_int ());
        }
        [GtkCallback]
        void on_sprite_move_up_btn_clicked () {
            scene_view.selection_move_up ();
            set_sprite_move_layer_sensitive (scene_view.selected_sprite);
        }

        [GtkCallback]
        void on_sprite_move_down_btn_clicked () {
            scene_view.selection_move_down ();
            set_sprite_move_layer_sensitive (scene_view.selected_sprite);
        }
        [GtkCallback]
        void on_remove_sprite_btn_clicked () {
            scene_view.selection_delete ();
        }
        [GtkCallback]
        void on_selected_sprite_changed () {
            if (scene_view.selected_sprite == null) return;
            if (selected_sprite.text.contains (".")) {
                selected_sprite.text = selected_sprite.text.replace (".", "");
            }
            scene_view.set_sprite_id (scene_view.selected_sprite, selected_sprite.get_text ());
        }

        void on_scene_view_selection_changed (Sprite? sprite) {
            // Nothing selected -> show scene properties
            bool scene_properties = sprite == null;
            set_sprite_ui_sensitive (!scene_properties);
            prop_w.set_editable (scene_properties);
            prop_h.set_editable (scene_properties);
            if (sprite == null) {
                prop_x.set_value (0);
                prop_y.set_value (0);
                prop_w.set_value (scene != null ? scene.width : 0);
                prop_h.set_value (scene != null ? scene.height : 0);
                selected_sprite.set_text (_("Scene"));
                return;
            }
            prop_x.adjustment.lower = scene_view.sprite_clamp_x (int.MIN, sprite);
            prop_x.adjustment.upper = scene_view.sprite_clamp_x (int.MAX, sprite);
            prop_x.set_value (sprite.x);

            prop_y.adjustment.lower = scene_view.sprite_clamp_y (int.MIN, sprite);
            prop_y.adjustment.upper = scene_view.sprite_clamp_y (int.MAX, sprite);
            prop_y.set_value (sprite.y);

            prop_w.set_value (sprite.icon.get_width ());
            prop_h.set_value (sprite.icon.get_height ());

            set_sprite_move_layer_sensitive (sprite);

            selected_sprite.set_text (sprite.id);
        }

        void load () {
            try {
                scene = new Scene.from_file (scene_file, project_dir_path);
                scene_view.scene = scene;
                scene_name_entry.set_text (Scene.get_basename_file (scene_file));
                set_ui_sensitive (true);
                scene_changed = false;

            } catch (Error e) {
                msg (_("Cannot load the scene"), e.message, Gtk.MessageType.ERROR);
            }
        }

        void save () {
            if (scene == null) return;
            try {
                scene.save (scene_file);
                scene_changed = false;
            } catch (Error e) {
                msg (_("Cannot save the scene"), e.message, Gtk.MessageType.ERROR);
            }
        }

        void unload_scene () {
            scene_file = null;
            scene_view.scene = null;
            scene = null;
            set_ui_sensitive (false);
        }

        void set_ui_sensitive (bool sensitive) {
            scene_name_entry.set_sensitive (sensitive);
            save_btn.sensitive = sensitive; delete_btn.sensitive = sensitive;
            if (!sensitive) {
                // Properties must be activated by selecting a sprite/scene
                // This is done in by handling selection change (View) signal when scene is loaded
                set_sprite_ui_sensitive (false);
                scene_name_entry.set_text ("");
            }
        }

        void set_sprite_ui_sensitive (bool sensitive) {
            prop_x.editable = sensitive;
            prop_y.editable = sensitive;
            prop_w.editable = sensitive;
            prop_h.editable = sensitive;
            selected_sprite.sensitive = sensitive;
            remove_sprite_btn.sensitive = sensitive;
            selected_sprite.sensitive = sensitive;
            sprite_move_down_btn.sensitive = sensitive;
            sprite_move_up_btn.sensitive = sensitive;
        }

        // Disables button that cannot be used for a specified sprite
        void set_sprite_move_layer_sensitive (Sprite sprite) {
            int i = scene_view.scene.get_sprite_layer (sprite);
            sprite_move_down_btn.sensitive = i > 0;
            sprite_move_up_btn.sensitive = i < scene_view.scene.sprites.size - 1;
        }

        public override bool delete_event (Gdk.EventAny event) {
            return check_file_save ();
        }

        bool check_file_save () {
            // Program not changed (no confirm dialog)
            if (!scene_changed)
                return false;
            // Program changed (show a confirm dialog)
            var dialog = new Gtk.MessageDialog (this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.NONE,
                _("Would you like to save your changes before closing the scene?"));
            dialog.secondary_text = _("Otherwise the unsaved changes will be lost!");
            dialog.add_buttons (
                _("Yes"), Gtk.ResponseType.YES,
                _("No"), Gtk.ResponseType.NO,
                _("Cancel"), Gtk.ResponseType.CANCEL
            );
            var answer = dialog.run ();
            dialog.destroy ();
            if (answer == Gtk.ResponseType.YES)
                save_btn.clicked ();
            else if (answer == Gtk.ResponseType.CANCEL)
                return true;
            return false;
        }

        void reload_resources () {
            new Thread<void> (null, () => {
                ArrayList<string> scenes = new ArrayList<string> ();
                ArrayList<Sprite?> sprites = new ArrayList<Sprite?> ();
                ArrayList<Gdk.Pixbuf> sprites_pb_fullres = new ArrayList<Gdk.Pixbuf> ();
                // Add default turtle sprite
                try {
                    Sprite turtle_sprite = new Sprite ();
                    turtle_sprite.name = "turtle";
                    var turtle_pixbuf = new Gdk.Pixbuf.from_resource (TURTLICO_RESOURCES + "icons/turtle_sprite.png");
                    turtle_sprite.icon = turtle_pixbuf;
                    sprites.add (turtle_sprite);
                    sprites_pb_fullres.add (turtle_pixbuf);
                } catch (Error e) {
                    warning (@"Cannot load default turtle sprite: $(e.message)");
                }

                var dir = File.new_for_path (project_dir_path);
                FileEnumerator enumerator;
                try {
                    enumerator = dir.enumerate_children (
                        "standard::*",
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                        null);
                } catch (Error e) {
                    string message = e.message;
                    Idle.add (() => {
                        msg (_("Error occurred while loading scenes and sprites"), message, Gtk.MessageType.ERROR);
                        return false;
                    });
                    return;
                }

                FileInfo info = null;
                try {
                    while ((info = enumerator.next_file (null)) != null) {
                        if (info.get_file_type () == FileType.REGULAR) {
                            string name = info.get_name (); // Basename
                            // Scenes
                            if (name.has_suffix (Scene.SCENE_FILE_SUFFIX)) {
                                if (name.has_prefix (project_name))
                                    scenes.add (Scene.get_basename (name));
                                continue;
                            }
                            // Sprites
                            bool is_image = false;
                            foreach (string ext in supported_image_exts) {
                                if (name.has_suffix (ext)) {
                                    is_image = true; break;
                                }
                            }
                            if (!is_image) continue;
                            try {
                                Sprite s = new Sprite ();
                                var sprite_path = Path.build_path (Path.DIR_SEPARATOR_S, project_dir_path, name);
                                var pixbuf = new Gdk.Pixbuf.from_file_at_size (
                                    sprite_path, SPRITES_PREVIEW_SIZE, SPRITES_PREVIEW_SIZE);
                                var pixbuf_fullres = new Gdk.Pixbuf.from_file (sprite_path);
                                s.name = name;
                                s.icon = pixbuf;
                                sprites.add (s);
                                sprites_pb_fullres.add (pixbuf_fullres);
                            } catch (Error e) {
                                string message = e.message;
                                debug ("Failed to load image '%s': '%s'".printf (name, message));
                            }
                        }
                    }
                } catch (Error e) {
                    string message = e.message;
                    Idle.add (()=>{
                        msg (_("Error occurred while loading scenes and sprites"), message, Gtk.MessageType.ERROR);
                        return false;
                    });
                }
                Idle.add (() => {
                    // Load data from async thread to  widgets
                    // Scenes
                    var current_scene_name = scene_file != null ? Scene.get_basename_file (scene_file) : "";
                    scenes_store.clear ();
                    foreach (var scene in scenes) {
                        Gtk.TreeIter iter;
                        scenes_store.append (out iter);
                        scenes_store.set (iter,
                            ScenesViewCols.NAME, scene);
                        if (scene == current_scene_name) {
                            scenes_view.get_selection ().select_iter (iter);
                        }
                    }
                    // Sprites
                    sprites_store.clear ();
                    scene_view.sprites.remove_all ();
                    for (int i = 0; i < sprites.size; i++) {
                        Sprite sprite = sprites[i];
                        Gtk.TreeIter iter;
                        sprites_store.append (out iter);
                        sprites_store.set (iter,
                            SpritesViewCols.NAME, sprite.name,
                            SpritesViewCols.ICON, sprite.icon);
                        // Load full size sprite Pixbufs into scene view
                        scene_view.sprites.set (sprite.name, sprites_pb_fullres[i]);
                    }
                    // Reload images of old sprites
                    scene_view.reload_resources ();

                    return Source.REMOVE;
                });
            });
        }

        void msg (string text, string secondary_text = "", Gtk.MessageType type = Gtk.MessageType.INFO) {
            var dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, type,
                                               Gtk.ButtonsType.OK, text);
            if (secondary_text != "") {
                dialog.secondary_text = secondary_text;
            }
            dialog.run ();
            dialog.destroy ();
        }
    }
}
