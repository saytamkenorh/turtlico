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
    enum CmdViewCols {
        PIXBUF,
        HELP,
        ID
    }

    [GtkTemplate (ui = "/io/gitlab/Turtlico/ui/window.ui")]
    public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        Gtk.Box toolbar_box;
        [GtkChild]
        Gtk.Box toolbar_box_left;
        [GtkChild]
        Gtk.Box toolbar_box_right;
        [GtkChild]
        Gtk.HeaderBar csd_headerbar;
        [GtkChild]
        Gtk.Box categories_box;
        [GtkChild]
        Gtk.IconView cmd_view;
        private double cmd_view_mx;
        private double cmd_view_my;
        [GtkChild]
        Gtk.ScrolledWindow cmd_view_sw;
        [GtkChild]
        Gtk.ScrolledWindow icons_scrolled_window;
        public ProgramView programview;
        public CodePreview code_preview;
        [GtkChild]
        Gtk.ScrolledWindow code_preview_scrolled_window;

        [GtkChild]
        Gtk.Button save_btn;
        [GtkChild]
        Gtk.Image delete_btn;
        [GtkChild]
        Gtk.Label status_label;
        [GtkChild]
        Gtk.Button run_btn;
        [GtkChild]
        Gtk.SearchBar search_bar;
        [GtkChild]
        Gtk.AboutDialog about_dialog;

        [GtkChild]
        Gtk.Button scene_editor_btn;

        public Compiler compiler; // Initialized in load_commands
        Debugger debugger = new Debugger ();
        SearchWidget search_widget;
        FunctionsDialog functions_dialog;
        SceneEditor.Window scene_editor = null;

        private File _current_file = null;
        File current_file {
            get {return _current_file;}
            set {
                _current_file = value;
                if (value != null)
                    programview.buffer.resource_dir = Path.get_dirname (current_file.get_path ());
                if (scene_editor != null) {
                    scene_editor.destroy (); scene_editor = null;
                }
                update_window_title ();
            }
        }

        Settings settings = new Settings ("io.gitlab.Turtlico");

        [GtkChild]
        Gtk.Image left_bar_btn_img;
        private bool _left_bar_pinned = true;
        bool left_bar_pinned {
            get {return _left_bar_pinned;}
            set {
                _left_bar_pinned = value;
                if (_left_bar_pinned) cmd_view_sw.show ();
                else cmd_view_sw.hide ();
                string i = _left_bar_pinned ? "sidebar-hide-symbolic" : "sidebar-show-symbolic";
                left_bar_btn_img.set_from_icon_name (i, Gtk.IconSize.BUTTON);
                settings.set_boolean ("left-sidebar-pinned", _left_bar_pinned);
            }
        }

        public Window (Gtk.Application app) {
            Object (application: app);
            string icon_file = Path.build_filename (
                Path.get_dirname (Environment.get_current_dir ()),
                "share/icons/hicolor/256x256/apps/io.gitlab.Turtlico.png");
            try {

                if (FileUtils.test (icon_file, FileTest.IS_REGULAR))
                    set_default_icon_from_file (icon_file);
            } catch {}

            // cmd view
            setup_cmd_view ();
            // ProgramView
            setup_program_view ();
            // Debugger
            debugger.on_error.connect ((title, message) => {
                msg (title, message, Gtk.MessageType.ERROR);
            });
            debugger.notify["debug-running"].connect (() => {
                string icon_name = "media-playback-" + (debugger.debug_running ? "stop" : "start");
                set_csd_icon (run_btn, icon_name);
            });
            // Search Widget
            search_widget = new SearchWidget (programview);
            search_bar.add (search_widget);
            search_bar.show_all ();
            // Functions Dialog
            functions_dialog = new FunctionsDialog (programview);
            setup_about_dialog ();
            // Code preview
            code_preview = new CodePreview (programview, compiler);
            code_preview_scrolled_window.add (code_preview);
            code_preview.show ();

            setup_accels (app);

            // Load commands database
            new_program (false); // load_commands is called in load_settings

            load_settings ("");
            settings.changed.connect (load_settings);

            update_window_title ();
            show_all ();
            left_bar_pinned = settings.get_boolean ("left-sidebar-pinned");
            programview.grab_focus ();
#if LINUX && !TURTLICO_FLATPAK
            linux_check_deps (this);
#endif
#if WINDOWS
            windows_check_updates (this);
#endif
        }

        void setup_cmd_view () {
            var cell_renderer = new Gtk.CellRendererPixbuf ();
            cmd_view.pack_start (cell_renderer, false);
            cmd_view.set_cell_data_func (cell_renderer, (layout, cell, model, iter)=>{
                Value pixbuf_val;
                model.get_value (iter, 0, out pixbuf_val);
                var pixbuf = (Gdk.Pixbuf)pixbuf_val;
                Cairo.Surface surface = Gdk.cairo_surface_create_from_pixbuf (
                    pixbuf, cmd_view.get_scale_factor (), cmd_view.get_window ());
                ((Gtk.CellRendererPixbuf)cell).surface = surface;
            });
            // target list is defined in programview
            Gtk.drag_source_set (
                cmd_view,                      // widget will be drag-able
                Gdk.ModifierType.BUTTON1_MASK, // modifier that will start a drag
                DND_TARGET_LIST,                   // lists of target to support
                Gdk.DragAction.COPY            // what to do with data after dropped
            );
            make_trash_widget (cmd_view);
            make_trash_widget (delete_btn);
            make_trash_widget (categories_box);
        }

        void make_trash_widget (Gtk.Widget widget) {
            Gtk.drag_dest_set (
                widget,                         // widget that will accept a drop
                Gtk.DestDefaults.ALL,           // default actions for dest on DnD
                DND_TARGET_LIST,                    // lists of target to support
                Gdk.DragAction.COPY
                | Gdk.DragAction.MOVE           // what to do with data after dropped
            );
        }

        void setup_program_view () {
            programview = new ProgramView ();
            icons_scrolled_window.add (programview);
            programview.buffer.notify["program-changed"].connect (() => {
                if (programview.buffer.program_changed)
                    save_btn.sensitive = true;
                else
                    save_btn.sensitive = false;
                update_window_title ();
            });
            programview.buffer.program_changed = false;
            programview.motion_notify_event.connect ((event) => {
                int x = (int)event.x / ProgramView.CELL_WIDTH;
                int y = (int)event.y / ProgramView.CELL_HEIGHT;
                x = programview.mouse_to_program_x (x, y);
                if (x >= 0 && y >= 0 && programview.buffer.program.size > y && programview.buffer.program[y].size > x) {
                    status_label.label = (x + 1).to_string () + ":" + (y + 1).to_string () +
                        " " + programview.buffer.program[y][x].definition.help;
                }
                else {
                    status_label.label = "";
                }
                return false;
            });
            programview.leave_notify_event.connect ((event) => {
                status_label.label = "";
                return false;
            });
            programview.button_release_event.connect ((button) => {
                if (!left_bar_pinned) cmd_view_sw.hide ();
                return false;
            });
        }

        void setup_about_dialog () {
            about_dialog.set_transient_for (this);
#if TURTLICO_FLATPAK
            about_dialog.set_logo_icon_name ("io.gitlab.Turtlico");
#else
            about_dialog.set_logo (null);
#endif
            about_dialog.version = TURTLICO_VERSION;
            about_dialog.website = TURTLICO_WEBPAGE;
        }

        void setup_accels (Gtk.Application app) {
            var search = new SimpleAction ("search", null);
            search.activate.connect (() => {
                search_bar.set_search_mode (!search_bar.search_mode_enabled);
            });
            app.add_action (search);
            app.set_accels_for_action ("app.search", {"<Primary>f"});
            var save_as = new SimpleAction ("save-as", null);
            save_as.activate.connect (this.save_as);
            app.add_action (save_as);
            app.set_accels_for_action ("app.save-as", {"<Control><Shift>s"});
            var new_project = new SimpleAction ("new-project", null);
            new_project.activate.connect (() => {
                if (check_file_save ()) return;
                new_program ();
            });
            app.add_action (new_project);
            app.set_accels_for_action ("app.new-project", {"<Control>n"});
        }

        [GtkCallback]
        void on_cmd_view_drag_begin (Gdk.DragContext context) {
            if (cmd_view.get_selected_items ().length () == 0)
                return;
            var selected_path = cmd_view.get_selected_items ().nth_data (0);
            Gtk.TreeIter selected_iter;
            cmd_view.get_model ().get_iter (out selected_iter, selected_path);
            string t;
            cmd_view.get_model ().get (selected_iter, CmdViewCols.ID, out t);
            try {
                ArrayList<ArrayList<Command>> c = new ArrayList<ArrayList<Command>> ();
                c.add (new ArrayList<Command>.wrap ({programview.buffer.find_command_by_id (t)}));
                var surface = programview.get_dnd_surface (c);
                Gtk.drag_set_icon_surface (context, surface);
            } catch {}
        }
        [GtkCallback]
        void on_cmd_view_drag_data_get (Gdk.DragContext context,
            Gtk.SelectionData selection_data, uint info, uint time_
        ) {
            if (cmd_view.get_selected_items ().length () == 0)
                return;
            var selected_path = cmd_view.get_selected_items ().nth_data (0);
            Gtk.TreeIter selected_iter;
            cmd_view.get_model ().get_iter (out selected_iter, selected_path);
            string t;
            cmd_view.get_model ().get (selected_iter, CmdViewCols.ID, out t);
            selection_data.set_text (t, t.length);
        }
        [GtkCallback]
        void on_cmd_view_drag_end (Gdk.DragContext context) {
            cmd_view.unselect_all ();
            if (!left_bar_pinned) cmd_view_sw.hide ();
        }

        [GtkCallback]
        void on_cmd_view_scale_factor_notify () {
            load_commands ();
        }

        [GtkCallback]
        bool on_cmd_view_motion_notify_event (Gdk.EventMotion event) {
            cmd_view_mx = event.x;
            cmd_view_my = event.y;
            return Gdk.EVENT_PROPAGATE;
        }

        [GtkCallback]
        bool on_cmd_view_key_press_event (Gdk.EventKey event) {
            if (event.keyval == Gdk.Key.F1) {
                var path = cmd_view.get_path_at_pos ((int)cmd_view_mx, (int)cmd_view_my);
                if (path == null)
                    return Gdk.EVENT_PROPAGATE;
                            Gtk.TreeIter selected_iter;
                cmd_view.get_model ().get_iter (out selected_iter, path);
                string id;
                cmd_view.get_model ().get (selected_iter, CmdViewCols.ID, out id);
                try {
                    programview.show_help_for (id);
                } catch (Error e) {
                    debug ("Cannot open help: " + e.message);
                }
            }
            return Gdk.EVENT_PROPAGATE;
        }

        [GtkCallback]
        void on_run_btn_clicked () {
            if (debugger.debug_running) {
                debugger.stop ();
                return;
            }
            debugger.start (compiler, programview.buffer, current_file);
        }

        [GtkCallback]
        void on_save_btn_clicked () {
            if (current_file != null) {
                try {
                    if (current_file.query_exists ())
                            current_file.delete ();
                    var ostream = current_file.create_readwrite (FileCreateFlags.NONE);
                    programview.buffer.save_to_stream (ostream.output_stream);
                    ostream.close ();
                }
                catch (Error e) {
                    msg (_("Failed to save the program"), e.message, Gtk.MessageType.ERROR);
                }
            }
            else
                save_as ();
            status_label.label = _("Project saved.");
        }

        void save_as () {
            #if TURTLICO_FLATPAK
            var dialog = new Gtk.FileChooserDialog (_("Select file"), this,
                                                   Gtk.FileChooserAction.SAVE,
                                                   _("Save"), Gtk.ResponseType.ACCEPT,
                                                   _("Cancel"), Gtk.ResponseType.CANCEL);
            #else
            var dialog = new Gtk.FileChooserNative (_("Select file"), this,
                                                   Gtk.FileChooserAction.SAVE,
                                                   null, null);
            #endif
            dialog.modal = true;
            var filter = new Gtk.FileFilter ();
            filter.add_pattern ("*.tcp");
            filter.set_filter_name (_("Turtlico project (*.tcp)"));
            dialog.add_filter (filter);
            int result = dialog.run ();
            if (result == Gtk.ResponseType.ACCEPT) {
                var file = dialog.get_file ();
                if (!file.get_path ().has_suffix (".tcp"))
                    file = File.new_for_path (file.get_path () + ".tcp");
                current_file = file;
                // Prevents infinite cycle
                if (file != null)
                    on_save_btn_clicked ();
            }
            #if TURTLICO_FLATPAK
                dialog.destroy ();
            #endif
            status_label.label = _("Program saved.");
        }

        [GtkCallback]
        void on_open_btn_clicked () {
            if (check_file_save ()) return;
            #if TURTLICO_FLATPAK
            var dialog = new Gtk.FileChooserDialog (_("Select file"), this,
                                                   Gtk.FileChooserAction.OPEN,
                                                   _("Open"), Gtk.ResponseType.ACCEPT,
                                                   _("Cancel"), Gtk.ResponseType.CANCEL);
            #else
            var dialog = new Gtk.FileChooserNative (_("Select file"), this,
                                                   Gtk.FileChooserAction.OPEN,
                                                   null, null);
            #endif
            dialog.modal = true;
            var filter = new Gtk.FileFilter ();
            filter.add_pattern ("*.tcp");
            filter.set_filter_name (_("Turtlico project (*.tcp)"));
            dialog.add_filter (filter);
            int result = dialog.run ();
            if (result == Gtk.ResponseType.ACCEPT) {
                var file = dialog.get_file ();
                if (!file.query_exists ())
                    return;
                open_file (file);
            }
            #if TURTLICO_FLATPAK
                dialog.destroy ();
            #endif
        }

        [GtkCallback]
        void on_settings_btn_clicked () {
            var previous_state = new Gee.ArrayList<string>.wrap (programview.buffer.enabled_plugins.to_array ());
            var program_settings = new ProgramSettings (programview.buffer,
                programview.buffer.program);
            program_settings.set_transient_for (this);
            program_settings.run ();
            program_settings.hide ();

            load_commands ();

            int remove_missing = -1;
            // Check for missing commands
            for (int y = 0; y < programview.buffer.program.size; y++) {
                for (int x = 0; x < programview.buffer.program[y].size; x++) {
                    bool found = false;
                    foreach (Command c in programview.buffer.commands) {
                        if (c.id == programview.buffer.program[y][x].id) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        if (remove_missing < 0) {
                            var dialog = new Gtk.MessageDialog (this,
                                Gtk.DialogFlags.MODAL,
                                Gtk.MessageType.WARNING,
                                Gtk.ButtonsType.YES_NO,
                                    _("Would you really like to apply these changes?"));
                            dialog.secondary_text =
                                _("The program contains commands that are only available from a plugin.") +
                                _("Unavailable commands will be removed.");
                            var answer = dialog.run ();
                            dialog.destroy ();
                            if (answer == Gtk.ResponseType.YES) {
                                remove_missing = 1;
                                programview.buffer.backup_clear ();
                            }
                            else {
                                programview.buffer.enabled_plugins = previous_state;
                                load_commands ();
                                y = programview.buffer.program.size;
                                break;
                            }
                        }
                        if (remove_missing == 1) {
                            programview.buffer.program[y].remove_at (x);
                            x--;
                        }
                    }
                }
                if (remove_missing == 1)
                    programview.buffer.backup_program ();
            }
        }

        [GtkCallback]
        void on_preferences_btn_clicked () {
            var app_settings = new AppSettings ();
            app_settings.set_transient_for (this);
            app_settings.show_all ();
        }

        [GtkCallback]
        void on_help_btn_clicked () {
            try {
                Gtk.show_uri_on_window (this, ProgramView.get_help_url () + "/index.html", Gdk.CURRENT_TIME);
            } catch (Error e) {
                warning ("Cannot open help: " + e.message);
            }
        }

        [GtkCallback]
        void on_about_btn_clicked () {
            about_dialog.run ();
            about_dialog.hide ();
        }

        [GtkCallback]
        void on_functions_btn_clicked () {
            functions_dialog.load_functions ();
            functions_dialog.set_transient_for (this);
            functions_dialog.run ();
            functions_dialog.hide ();
        }

        [GtkCallback]
        void on_scene_editor_btn_clicked () {
            if (current_file == null) {
                msg (_("Please save the program before opening the scene editor."), "", Gtk.MessageType.INFO);
                return;
            }
            if (scene_editor == null) {
                scene_editor = new SceneEditor.Window (current_file, programview);
                scene_editor.destroy.connect (() => {scene_editor=null;});
                get_application ().add_window (scene_editor);
            }
            scene_editor.present ();
        }

        public void open_file (File file) {
            bool ignore_errors = false;
            for (int i = 0; i < 2; i++) { // Limit max attempts to 2
                try {
                    var stream = file.read ();
                    current_file = file;
                    programview.buffer.load_from_stream_ (stream, true, ignore_errors);
                    load_commands ();
                    stream = file.read ();
                    programview.buffer.load_from_stream_ (stream, false, ignore_errors);
                    stream.close ();
                    return;
                }
                catch (Error e) {
                    var dialog = new Gtk.MessageDialog (this,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.ERROR,
                        Gtk.ButtonsType.YES_NO,
                        e.message);
                    dialog.secondary_text = _("Would you like to continue loading anyway and ignore further errors?");
                    var answer = dialog.run ();
                    dialog.destroy ();
                    if (answer == Gtk.ResponseType.NO) {
                        new_program ();
                        return;
                    }
                    ignore_errors = true;
                }
            }
        }

        public void new_program (bool reload_commands = true) {
            current_file = null;
            programview.buffer.new_program ();
            if (reload_commands)
                load_commands ();
        }

        void load_commands () {
            // Clear
            categories_box.get_children ().foreach ((w) => {categories_box.remove (w);});
            programview.buffer.commands.clear ();
            search_widget.find_entry.buffer.commands.clear ();
            search_widget.replace_entry.buffer.commands.clear ();
            // Compiler
            programview.buffer.enabled_plugins.sort ();
            try {
                compiler = new Compiler (programview.buffer.enabled_plugins.to_array ());
            } catch (FileError e) {
                debug (e.message);
                return;
            }
            code_preview.compiler = compiler;

            // Load categories
            CommandCategory[] categories;
            try {
                categories = CommandCategory.get_command_categories (
                    programview.buffer.enabled_plugins.to_array (), get_scale_factor ());
            } catch (FileError e) {
                debug (e.message);
                return;
            }
            foreach (var category in categories) {
                // Create widgets
                var string_type = typeof (string);
                Gtk.ListStore ls = new Gtk.ListStore (3, typeof (Gdk.Pixbuf), string_type, string_type);
                var button = new Gtk.RadioButton (null);
                if (category.icon != null) {
                    Cairo.Surface img = Gdk.cairo_surface_create_from_pixbuf (
                                category.icon, get_scale_factor (), get_window ());
                    button.image = new Gtk.Image.from_surface (img);
                }
                else
                    button.label = category.icon_path;
                button.can_focus = false;
                button.set_mode (false);
                if (categories_box.get_children ().length () > 0) {
                    Gtk.RadioButton rb = (Gtk.RadioButton)categories_box.get_children ().nth_data (0);
                    button.join_group (rb);
                }
                button.clicked.connect ((btn) => {
                    cmd_view.set_model (ls);
                    cmd_view_sw.show ();
                    // FIXME: This hack is used in order to prevent
                    // invisibility of icons after DnD data receive.
                    // It should be fixed in a more proper way.
                    Gtk.Allocation al;
                    cmd_view.get_allocation (out al);
                    cmd_view.size_allocate (al);
                });
                categories_box.pack_start (button, false, false);
                // Load commands
                foreach (var c in category.commands) {
                    programview.buffer.commands.add (c);
                    search_widget.find_entry.buffer.commands.add (c);
                    search_widget.replace_entry.buffer.commands.add (c);
                    Gtk.TreeIter iter;
                    ls.append (out iter);
                    ArrayList<ArrayList<Command>> clist = new ArrayList<ArrayList<Command>> ();
                    clist.add (new ArrayList<Command>.wrap ({c}));
                    var surface = programview.get_dnd_surface (clist);
                    var pixbuf = Gdk.pixbuf_get_from_surface (surface, 0, 0,
                        surface.get_width (), surface.get_height ());
                    ls.set (iter,
                        CmdViewCols.PIXBUF, pixbuf,
                        CmdViewCols.HELP, c.definition.help,
                        CmdViewCols.ID, c.id);
                }
            }

            categories_box.show_all ();
            Gtk.RadioButton rb = (Gtk.RadioButton)categories_box.get_children ().nth_data (1);
            rb.clicked ();
            rb = (Gtk.RadioButton)categories_box.get_children ().nth_data (0);
            rb.clicked ();

            scene_editor_btn.visible = programview.buffer.enabled_plugins.contains ("r:0turtle.json");
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

        void load_settings (string key) {
            bool update_all = key == "";
            if (key == "dark-mode" || update_all) {
                var gtk_settings = Gtk.Settings.get_default ();
                gtk_settings.gtk_application_prefer_dark_theme = settings.get_boolean ("dark-mode");
            }
            if (key == "dark-icons" || update_all) {
                programview.high_contrast = settings.get_boolean ("dark-icons");
                load_commands ();
            }
            if (key == "auto-indent" || update_all) {
                programview.auto_indent = settings.get_boolean ("auto-indent");
            }
            if (key == "csd" || update_all) {
                set_csd (settings.get_boolean ("csd"));
            }
            if (key == "code-preview" || update_all) {
                code_preview_scrolled_window.visible = settings.get_boolean ("code-preview");
            }
        }

        void set_csd (bool csd) {
            // Prevents Window reappearance when csd is not changed
            if (!csd == (get_titlebar () == null)) return;
            // Remove right and left toolbar box from its current parent
            toolbar_box.remove (toolbar_box_left);
            toolbar_box.remove (toolbar_box_right);
            csd_headerbar.remove (toolbar_box_left);
            csd_headerbar.remove (toolbar_box_right);

            set_titlebar (null);
            delete_btn.visible = !csd;

            if (csd) {
                csd_headerbar.pack_start (toolbar_box_left);
                csd_headerbar.pack_end (toolbar_box_right);
                set_titlebar (csd_headerbar);
                csd_headerbar.show_all ();
            }
            else {
                toolbar_box.pack_start (toolbar_box_left, true, true);
                toolbar_box.pack_end (toolbar_box_right, false, false);
            }
            // Reload icons
            foreach (var child in toolbar_box_left.get_children ())
                set_csd_icon (child);
            foreach (var child in toolbar_box_right.get_children ())
                set_csd_icon (child);
            update_window_title ();
        }

        void set_csd_icon (Gtk.Widget widget, owned string icon = "") {
            if (!(widget is Gtk.Button)) return;
            Gtk.Button btn = (Gtk.Button)widget;
            if (btn.image == null) return;
            if (!(btn.image is Gtk.Image)) return;
            Gtk.Image img = (Gtk.Image)btn.image;
            if (icon == "") {
                icon = img.icon_name;
                if (icon == null) return;
                icon = icon.replace ("-symbolic", "");
            }
            if (this.get_titlebar () != null) icon+="-symbolic";
            img.set_from_icon_name (icon, Gtk.IconSize.BUTTON);
        }

        [GtkCallback]
        void on_undo_btn_clicked () {
            programview.buffer.undo ();
        }

        [GtkCallback]
        void on_redo_btn_clicked () {
            programview.buffer.redo ();
        }

        [GtkCallback]
        bool on_categories_box_eb_scroll_event (Gtk.Widget widget, Gdk.EventScroll event) {
            int direction = 0;
            if (event.direction == Gdk.ScrollDirection.DOWN)
                direction = 1;
            else if (event.direction == Gdk.ScrollDirection.UP)
                direction = -1;
            else if (event.direction == Gdk.ScrollDirection.SMOOTH)
                direction = event.delta_y < 0 ? -1 : 1;

            var children = categories_box.get_children ();
            int index = 0;
            for (int i = 0; i < children.length (); i++) {
                Gtk.ToggleButton btn = (Gtk.ToggleButton)children.nth_data (i);
                if (btn.active)
                    index = i + direction;
            }

            if (index < 0) index = (int)children.length () - 1;
            if (index >= children.length ()) index = 0;

            ((Gtk.ToggleButton)children.nth_data (index)).clicked ();
            return false;
        }

        public override bool delete_event (Gdk.EventAny event) {
            if (scene_editor != null) scene_editor.close ();
            return check_file_save ();
        }

        private bool check_file_save () {
            // Program not changed (no confirm dialog)
            if (!programview.buffer.program_changed)
                return false;
            // Program changed (show a confirm dialog)
            var dialog = new Gtk.MessageDialog (this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.NONE,
                _("Would you like to save your changes before closing the program?"));
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

        void update_window_title () {
            string name = "";
            if (programview.buffer.program_changed)
                name = "*";
            if (current_file == null)
                name += _("Unnamed");
            else
                name += current_file.get_basename ();
            if (get_titlebar () != null) {
                csd_headerbar.set_title (name);
                return;
            }
            title = name + " - Turtlico";
        }

        [GtkCallback]
        void on_left_bar_btn_clicked () {
            left_bar_pinned = !left_bar_pinned;
        }
    }
}
