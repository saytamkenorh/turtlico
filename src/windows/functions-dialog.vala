/* functions-dialog.vala
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

namespace Turtlico {
    [GtkTemplate (ui = "/io/gitlab/Turtlico/windows/functions-dialog.ui")]
    class FunctionsDialog : Gtk.Dialog {
        protected ProgramView programview;
        [GtkChild]
        Gtk.ListBox listbox;
        [GtkChild]
        Gtk.RadioButton rb_none;
        [GtkChild]
        Gtk.Box event_type_box;
        [GtkChild]
        Gtk.Stack view_stack;
        [GtkChild]
        Gtk.Entry name_entry;
        [GtkChild]
        Gtk.Button create_btn;

        string selected_event_connector = "";
        string selected_event_code = "";
        string selected_event_params = "";

        public FunctionsDialog (ProgramView programview) {
            this.programview = programview;
            show.connect (() => load_functions);
            load_functions ();
        }

        public void load_functions () {
            listbox.get_children ().foreach ((child) => {child.destroy ();});
            for (int line = 0; line < programview.buffer.program.size; line++) {
                for (int command = 0; command < programview.buffer.program[line].size - 1; command++) {
                    Command c = programview.buffer.program[line][command];
                    if (c.id == "3_def") {
                        // Check for name
                        Command obj = programview.buffer.program[line][command + 1];
                        if (obj.id == "obj") {
                            string name = obj.data;
                            var row = new FunctionRow (name, command, line);
                            listbox.add (row);
                            row.use_clicked.connect (on_listbox_row_use_btn_clicked);
                            row.show_all ();
                        }
                    }
                }
            }
            // Load event types
            rb_none.clicked ();
            event_type_box.get_children ().foreach ((child) => {child.destroy ();});
            var parsers = Command.create_parsers (programview.buffer.enabled_plugins.to_array ());
            foreach (Json.Parser parser in parsers) {
                // Get the root node:
                Json.Node node = parser.get_root ();
                if (!node.get_object ().has_member ("events")) continue;
                var module_events = node.get_object ().get_array_member ("events");
                module_events.foreach_element ((array, index_, event_node) => {
                    // Parse one command
                    Json.Object event = event_node.get_object ();
                    Gtk.RadioButton rb = new Gtk.RadioButton.from_widget (rb_none);
                    rb.label = _(event.get_string_member ("name"));
                    event_type_box.pack_start (rb, false, false, 0);
                    rb.clicked.connect (() => {
                        if (event.has_member ("connector"))
                            selected_event_connector = event.get_string_member ("connector");
                        if (event.has_member ("code"))
                            selected_event_code = event.get_string_member ("code");
                        if (event.has_member ("params"))
                            selected_event_params = event.get_string_member ("params");
                    });
                    rb.show ();
                });
            }
            view_stack.set_visible_child_name ("list");
        }

        [GtkCallback]
        void on_listbox_row_activated (Gtk.ListBoxRow _row) {
            var row = (FunctionRow)_row;
            programview.buffer.selection_select (row.command, row.line, row.command + 1, row.line);
            programview.scroll_to_selection ();
            response (0);
        }

        void on_listbox_row_use_btn_clicked (FunctionRow row) {
            programview.paste_data (
                @"obj;$(row.function_name)~(;~);~".replace ("~", ProgramBuffer.str_mark_utf8));
            response (0);
        }

        [GtkCallback]
        void on_add_btn_clicked () {
            view_stack.set_visible_child_name ("create");
            set_default (create_btn);
        }

        [GtkCallback]
        void on_cancel_btn_clicked () {
            view_stack.set_visible_child_name ("list");
        }

        [GtkCallback]
        void on_create_btn_clicked () {
            int x = 0;
            int y = programview.buffer.program.size;
            string code = selected_event_connector.replace ("~", ProgramBuffer.str_mark_utf8);
            code = code.replace ("$name", name_entry.text);
            try {
                programview.buffer.paste_icons_string (
                    code, ref x, ref y, false, programview.auto_indent);

                // Get function line
                y = 0;
                int first_def = int.MAX;
                int last_global = int.MAX;
                for (int line = 0; line < programview.buffer.program.size; line++) {
                    if (programview.buffer.program[line].size == 0) continue;
                    if (programview.buffer.program[line][0].id == "3_def" && line < first_def)
                        first_def = line;
                    if (programview.buffer.program[line][0].id == "3_global")
                        last_global = line + 1;
                }
                if (first_def != int.MAX || last_global != int.MAX)
                    y = int.min (first_def, last_global);

                var builder = new StringBuilder ();
                if (programview.buffer.check_coord_valid (0, y - 1) &&
                    programview.buffer.program[y - 1][0].id != "nl"
                ) {
                    builder.append ("nl;~");
                }
                builder.append (@"3_def;~obj;$(name_entry.text)~(;~");
                int i = 0;
                foreach (var param in selected_event_params.split (",")) {
                    if (i > 0) builder.append ("sep;~");
                    builder.append (@"obj;$param~");
                    i++;
                }
                string function_code = selected_event_code.replace ("$name", name_entry.text);
                builder.append (@");~:;~nl;~tab;~$(function_code)nl;~");
                programview.buffer.paste_icons_string (
                    builder.str, ref x, ref y, false, programview.auto_indent);
            } catch {}
            view_stack.set_visible_child_name ("create");
            response (0);
        }
    }

    class FunctionRow : Gtk.ListBoxRow {
        public signal void goto ();
        public signal void use ();

        public string function_name;
        public int command {get; private set;}
        public int line {get; private set;}

        public signal void use_clicked (FunctionRow row);

        public FunctionRow (string function_name, int command, int line) {
            this.function_name = function_name;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
            var use_btn = new Gtk.Button.with_label ("🆔");
            use_btn.tooltip_text = _("Use this function");
            use_btn.clicked.connect (() => {
                use_clicked (this);
            });
            box.pack_start (use_btn, false, false, 0);
            var label = new Gtk.Label (function_name);
            box.pack_start (label, true, true, 0);
            add (box);

            this.command = command;
            this.line = line;
        }
    }
}
