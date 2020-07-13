/* scene-editor-view.vala
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
    [GtkTemplate (ui = "/io/gitlab/Turtlico/widgets/scene-editor-view.ui")]
    class View : Gtk.DrawingArea {
        private Scene _scene = null;
        public Scene scene {
            get {
                return _scene;
            }
            set {
                _scene = value;
                selected_sprite = null;
                selection_changed (null);
                if (scene != null) {
                    scene.notify.connect (() => {
                        set_size_request (scene.width + 50, scene.height + 50); queue_draw ();
                    });
                    set_size_request (scene.width + 50, scene.height + 50);
                }
                else {
                    set_size_request (-1, -1);
                }
                queue_draw ();
            }
        }
        public HashTable<string, Gdk.Pixbuf> sprites = new HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);
        protected ProgramView programview;
        public Sprite? selected_sprite = null;
        bool selection_move = false;
        int selection_offset_x = 0;
        int selection_offset_y = 0;

        public signal void selection_changed (Sprite? sprite);
        public signal void selection_moved ();
        public signal void scene_changed ();

        public View (ProgramView programview) {
            add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
            add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
            add_events (Gdk.EventMask.POINTER_MOTION_MASK);
            Gtk.drag_dest_set (
                this,
                Gtk.DestDefaults.DROP | Gtk.DestDefaults.MOTION,
                DND_TARGET_LIST,
                Gdk.DragAction.COPY);
            this.programview = programview;
        }

        public override bool draw (Cairo.Context cr) {
            Gtk.Allocation allocation;
            get_allocation (out allocation);
            var style_context = get_style_context ();

            if (scene == null) {
                // Draw a white bg and a text
                cr.set_source_rgba (1, 1, 1, 1);
                cr.rectangle (
                    allocation.x, allocation.y, allocation.width, allocation.height);
                cr.fill ();
                cr.move_to (0, allocation.height / 2);

                Gdk.cairo_set_source_rgba (cr, style_context.get_color (get_state_flags ()));

                Pango.Layout layout = create_pango_layout (_("No scene opened"));
                layout.set_alignment (Pango.Alignment.CENTER);
                layout.set_width (allocation.width * Pango.SCALE);
                Pango.cairo_show_layout (cr, layout);
                return false;
            }
            // Background
            cr.set_source_rgba (0.3, 0.3, 0.3, 1);
            cr.rectangle (
                allocation.x, allocation.y, allocation.width, allocation.height);
            cr.fill ();
            cr.set_source_rgba (1, 1, 1, 1);
            cr.rectangle (
                allocation.x, allocation.y, scene.width, scene.height);
            cr.fill ();
            // Foreground
            foreach (var sprite in scene.sprites) {
                int x = x_from_turtle (sprite.x) - sprite.icon.get_width () / 2;
                int y = y_from_turtle (sprite.y) - sprite.icon.get_height () / 2;
                Gdk.cairo_set_source_pixbuf (cr, sprite.icon, x, y);
                cr.paint ();
            }
            // Selection
            if (selected_sprite != null) {
                int width = selected_sprite.icon.get_width ();
                int height = selected_sprite.icon.get_height ();
                cr.set_line_width (2);
                cr.set_source_rgba (0.241, 0.53, 0.918, 1);
                cr.rectangle (
                    x_from_turtle (selected_sprite.x) - width / 2,
                    y_from_turtle (selected_sprite.y) - height / 2,
                    width, height);
                cr.stroke ();
            }

            return false;
        }

        [GtkCallback]
        bool on_button_press_event (Gtk.Widget widget, Gdk.EventButton event) {
            if (scene == null) return false;
            if (event.button == Gdk.BUTTON_PRIMARY) {
                Sprite? sprite = get_sprite_at_pos ((int)event.x, (int)event.y);
                selected_sprite = null;
                selection_changed (sprite);
                selected_sprite = sprite;
                selection_move = (sprite != null);
                if (sprite != null) {
                    selection_offset_x = x_to_turtle ((int)event.x) - sprite.x;
                    selection_offset_y = y_to_turtle ((int)event.y) - sprite.y;
                }
                queue_draw ();
            }
            if (event.button == Gdk.BUTTON_SECONDARY) {
                Sprite? sprite = get_sprite_at_pos ((int)event.x, (int)event.y);
                if (sprite != null) {
                    programview.paste_data (
                        @"obj;$(sprite.id)~".replace ("~", ProgramBuffer.str_mark_utf8));
                }
                var toplevel = programview.get_toplevel ();
                if (toplevel is Gtk.Window)
                    ((Gtk.Window)toplevel).present ();
            }
            return false;
        }

        Sprite? get_sprite_at_pos (int x, int y) {
            var mouse_rect = Gdk.Rectangle () {
                x = x_to_turtle (x), y = y_to_turtle (y),
                width = 1, height = 1};
            foreach (var s in scene.sprites) {
                var sprite_rect = Gdk.Rectangle () {
                    x=s.x - s.icon.get_width () / 2, y=s.y - s.icon.get_height () / 2,
                    width=s.icon.get_width (), height=s.icon.get_height ()
                };
                if (mouse_rect.intersect (sprite_rect, null)) {
                    return s;
                }
            }
            return null;
        }

        [GtkCallback]
        bool on_button_release_event (Gtk.Widget widget, Gdk.EventButton event) {
            if (event.button == Gdk.BUTTON_PRIMARY) {
                selection_move = false;
            }
            return false;
        }

        [GtkCallback]
        bool on_motion_notify_event (Gdk.EventMotion event) {
            if (selection_move && selected_sprite != null) {
                int x = x_to_turtle ((int)event.x) - selection_offset_x;
                int y = y_to_turtle ((int)event.y) - selection_offset_y;
                x = int.max (-scene.width / 2, int.min (
                    scene.width / 2 + selected_sprite.icon.get_width () / 2, x));
                y = int.max (-scene.height / 2 - selected_sprite.icon.get_height () / 2, int.min (
                    scene.height / 2, y));
                set_sprite_x (selected_sprite, x);
                set_sprite_y (selected_sprite, y);
                selection_moved ();
            }
            return false;
        }

        [GtkCallback]
        void on_drag_data_received (Gdk.DragContext context, int x, int y,
            Gtk.SelectionData selection_data, uint info, uint time
        ) {
            int length = selection_data.get_length ();
            bool success = false;

            if (length > 0 && selection_data.get_format () == 8) {
                string data = selection_data.get_text ();
                success = paste_sprite (data, x, y);
            }
            Gtk.drag_finish (context, success, false, time);
        }

        public void selection_delete () {
            scene.sprites.remove (selected_sprite);
            selected_sprite = null;
            selection_changed (null);
            queue_draw ();
        }

        public int x_to_turtle (int x) { return x - scene.width / 2; }
        public int y_to_turtle (int y) { return - (y - scene.height / 2); }
        public int x_from_turtle (int x) { return x + scene.width / 2; }
        public int y_from_turtle (int y) { return -y + scene.height / 2; }

        bool paste_sprite (string name, int x, int y) {
            if (sprites == null || scene == null) return false;
            if (!sprites.contains (name)) return false;
            Sprite sprite = new Sprite ();
            sprite.name = name;
            sprite.icon = sprites[name];

            // Choose id
            int n = 0;
            bool id_exists = true;
            while (id_exists) {
                id_exists = false;
                foreach (var s in scene.sprites) {
                    if (s.id == "%s%d".printf (name, n)) {
                        n++;
                        id_exists = true;
                        break;
                    }
                }
            }
            string id = "%s%d".printf (name.replace (".", ""), n);
            sprite.id = id;
            sprite.x = x_to_turtle (x);
            sprite.y = y_to_turtle (y);
            scene.sprites.add (sprite);
            scene_changed ();
            queue_draw ();
            return true;
        }

        public void set_scene_width (int width) {
            if (width == scene.width) return;
            scene.width = width; scene_changed (); queue_draw ();
        }
        public void set_scene_height (int height) {
            if (height == scene.height) return;
            scene.height = height; scene_changed (); queue_draw ();
        }
        public void set_sprite_x (Sprite s, int x) {
            if (x == s.x) return;
            s.x = x; scene_changed (); queue_draw ();
        }
        public void set_sprite_y (Sprite s, int y) {
            if (y == s.y) return;
            s.y = y; scene_changed (); queue_draw ();
        }
        public void set_sprite_id (Sprite s, string id) {
            if (id == s.id) return;
            s.id = id.replace (".", ""); scene_changed (); queue_draw ();
        }
    }
}
