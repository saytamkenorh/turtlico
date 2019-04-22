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
	enum CmdViewCols
    {
        NAME,
        HELP,
        ID
    }

	[GtkTemplate (ui = "/com/orsan/Turtlico/window.ui")]
	public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        Gtk.Box categories_box;
        [GtkChild]
        Gtk.IconView cmd_view;
        [GtkChild]
        Gtk.ScrolledWindow icons_scrolled_window;
        public ProgramView programview;

        [GtkChild]
        Gtk.Image delete_btn;

        public Compiler compiler = new Compiler();
        File current_file = null;

		public Window (Gtk.Application app) {
			Object (application: app);
            // CSS
            var screen = this.get_screen ();
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_resource("/com/orsan/Turtlico/window.css");
            Gtk.StyleContext.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

			// cmd view
			cmd_view.set_text_column(0);
            Gtk.drag_source_set(
                cmd_view,                      // widget will be drag-able
                Gdk.ModifierType.BUTTON1_MASK, // modifier that will start a drag
                target_list,                   // lists of target to support
                Gdk.DragAction.COPY            // what to do with data after dropped
            );
            // delete btn
             Gtk.drag_dest_set (
                delete_btn,                     // widget that will accept a drop
                Gtk.DestDefaults.ALL,           // default actions for dest on DnD
                target_list,                    // lists of target to support
                Gdk.DragAction.COPY
                | Gdk.DragAction.MOVE           // what to do with data after dropped
            );
            // ProgramView
            programview = new ProgramView();
            icons_scrolled_window.add(programview);
            // Load commands database
            load_commands();

            Gtk.RadioButton rb = (Gtk.RadioButton)categories_box.get_children().nth_data(1);
            rb.clicked();
            rb = (Gtk.RadioButton)categories_box.get_children().nth_data(0);
            rb.clicked();

			show_all();
			programview.grab_focus();
		}

		[GtkCallback]
		void on_cmd_view_drag_begin (Gdk.DragContext context) {
            var surface = new Cairo.ImageSurface(Cairo.Format.RGB24,
                                                 ProgramView.cell_width, ProgramView.cell_height);
            var ctx = new Cairo.Context(surface);
            if (cmd_view.get_selected_items().length() == 0)
                return;
            var selected_path = cmd_view.get_selected_items().nth_data(0);
            Gtk.TreeIter selected_iter;
            cmd_view.get_model().get_iter(out selected_iter, selected_path);
            string t;
            cmd_view.get_model().get(selected_iter, CmdViewCols.ID, out t);
            try {
                programview.draw_icon(ctx, 0, 0, programview.find_command_by_id(t));
            }
            catch {}
            var pixbuf = Gdk.pixbuf_get_from_surface(surface, 0, 0, ProgramView.cell_width, ProgramView.cell_height);
            Gtk.drag_set_icon_pixbuf(context, pixbuf, ProgramView.cell_width / 2, ProgramView.cell_height / 2);
		}
		[GtkCallback]
		void on_cmd_view_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time_) {
            if (cmd_view.get_selected_items().length() == 0)
                return;
            var selected_path = cmd_view.get_selected_items().nth_data(0);
            Gtk.TreeIter  selected_iter;
            cmd_view.get_model().get_iter(out selected_iter, selected_path);
            string t;
            cmd_view.get_model().get(selected_iter, CmdViewCols.ID, out t);
            selection_data.set_text(t, t.length);
		}
		[GtkCallback]
		void on_cmd_view_drag_end (Gdk.DragContext context) {
            cmd_view.unselect_all();
		}

		[GtkCallback]
		void on_run_btn_clicked() {
            try {
                string output = compiler.compile(programview.program);
                string path;
                if (current_file != null && !current_file.get_path().has_prefix("/run/user"))
                    path = current_file.get_path() + ".py";
                else
                    path = Path.build_filename(Environment.get_user_cache_dir(), "turtlico_output.py");
                // Save generated program
                var file = File.new_for_path (path);
                if (file.query_exists ()) {file.delete ();}
                var dos = new DataOutputStream (file.create (FileCreateFlags.NONE));
                uint8[] data = output.data;
                long written = 0;
                while (written < data.length) {
                    // sum of the bytes of 'data' that already have been written to the stream
                    written += dos.write (data[written:data.length]);
                }
                // RUN
                #if linux
                GLib.Process.spawn_command_line_sync("chmod +x '" + path + "'");
                #endif
                GLib.Process.spawn_command_line_sync("python3 '" + path + "'");
            }
            catch (Error e) {
                msg(e.message, "", Gtk.MessageType.ERROR);
            }
		}

        [GtkCallback]
        void on_save_btn_clicked() {
            if (current_file != null) {
                try {
                    if (current_file.query_exists())
                            current_file.delete();
                    var ostream = current_file.create_readwrite(FileCreateFlags.NONE);
                    programview.save_to_stream(ostream.output_stream);
                    ostream.close();
                }
                catch (Error e) {
                    msg(_("Failed to save the program"), e.message, Gtk.MessageType.ERROR);
                }
            }
            else
                on_save_as_btn_clicked();
        }

        [GtkCallback]
        void on_save_as_btn_clicked() {
            var dialog = new Gtk.FileChooserNative(_("Select file"), this,
                                                   Gtk.FileChooserAction.SAVE,
                                                   null, null);
            dialog.modal = true;
            var filter = new Gtk.FileFilter();
            filter.add_pattern("*.tcp");
            filter.set_filter_name(_("Turtlico project (*.tcp)"));
            dialog.add_filter(filter);
            int result = dialog.run();
            if (result == Gtk.ResponseType.ACCEPT) {
                var file = dialog.get_file();
                current_file = file;
                // Prevents infinite cycle
                if (file != null)
                    on_save_btn_clicked();
            }
        }

        [GtkCallback]
        void on_open_btn_clicked() {
            var dialog = new Gtk.FileChooserNative(_("Select file"), this,
                                                   Gtk.FileChooserAction.OPEN,
                                                   null, null);
            dialog.modal = true;
            var filter = new Gtk.FileFilter();
            filter.add_pattern("*.tcp");
            filter.set_filter_name(_("Turtlico project (*.tcp)"));
            dialog.add_filter(filter);
            int result = dialog.run();
            if (result == Gtk.ResponseType.ACCEPT) {
                var file = dialog.get_file();
                if (!file.query_exists())
                    return;
                open_file(file);
            }
        }

        public void open_file (File file) {
            try {
                var ostream = file.read();
                programview.load_from_stream(ostream);
                ostream.close();
                current_file = file;
            }
            catch (Error e) {
                msg(_("Failed to open the program"), e.message, Gtk.MessageType.ERROR);
            }
        }

        void load_commands () {
            // Load from JSON
            var parsers = Command.create_parsers();
            foreach(Json.Parser parser in parsers) {
                // Get the root node:
		        Json.Node node = parser.get_root ();
		        // For all commands in all categories
                var categories = node.get_object().get_array_member("categories");
                categories.foreach_element((array, index_, category_node)=>{
                    // Create widgets
                    var string_type = typeof(string);
                    Gtk.ListStore ls = new Gtk.ListStore(3, string_type, string_type, string_type);
                    var button = new Gtk.RadioButton(null);
                    button.label = category_node.get_object().get_string_member("icon");
                    button.can_focus = false;
                    button.set_mode(false);
                    if(categories_box.get_children().length() > 0) {
                        Gtk.RadioButton rb = (Gtk.RadioButton)categories_box.get_children().nth_data(0);
                        button.join_group(rb);
                    }
                    button.toggled.connect((btn)=>{
                        if(btn.active) cmd_view.set_model(ls);
                    });
                    categories_box.pack_start(button, false, false);
                    // Add commands to prograview and liststore
                    var commands = category_node.get_object().get_array_member("commands");
                    commands.foreach_element((array, index_, command_node)=>{
                        // Parse one command
                        Json.Object command = command_node.get_object();
                        Command c = new Command(command.get_string_member("icon"),
                                                _(command.get_string_member("?")),
                                                command.get_string_member("id"), "");
                        //debug(command.get_string_member("icon"));
                        programview.commands.add(c);
                        Gtk.TreeIter iter;
                        ls.append(out iter);
                        ls.set(iter,
                               CmdViewCols.NAME, c.name,
                               CmdViewCols.HELP, c.help,
                               CmdViewCols.ID, c.id);
                    });
                });
            }
            // end foreach
        }

        void msg (string text, string secondary_text = "", Gtk.MessageType type = Gtk.MessageType.INFO) {
            var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, type,
                                               Gtk.ButtonsType.OK, text);
            if(secondary_text != "") {
                dialog.secondary_text = secondary_text;
            }
            dialog.run();
            dialog.destroy();
        }
	}
}
