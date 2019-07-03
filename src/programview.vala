/* programview.vala
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
    public enum DnDTarget {
        STRING
    }
	public const Gtk.TargetEntry[] target_list = {
        { "STRING",     0, DnDTarget.STRING },
        { "text/plain", 0, DnDTarget.STRING },
    };
    private enum SelectionPhase {
        NOTHING_SELECTED,
        SELECT_END,
        BLOCK_SELECTED
    }

    [GtkTemplate (ui = "/com/orsan/Turtlico/programview.ui")]
    public class ProgramView : Gtk.DrawingArea {
        public const int cell_width = 50;
        public const int cell_height = 35;
        public ArrayList<Command> commands = new ArrayList<Command>();
        public ArrayList<ArrayList<Command>> program  = new ArrayList<ArrayList<Command>>();
        private ArrayList<ArrayList<ArrayList<Command>>> history  = new ArrayList<ArrayList<ArrayList<Command>>>();
        private int history_index = 0;
        public int history_buffer_size = 20;
        public ArrayList<string> enabled_plugins = new ArrayList<string>();
        private bool _program_changed = true;
        public bool program_changed {
            get { return _program_changed; }
            set { _program_changed = value; }
        }
        // Selection
        private Gdk.Point selection_start;
        private Gdk.Point selection_end;
        private int selection_phase = SelectionPhase.NOTHING_SELECTED;
        // Used in drag_data_get
        int mouse_x;
        int mouse_y;
        // Widgets
        [GtkChild]
        Gtk.Dialog num_chooser_dialog;
        [GtkChild]
        Gtk.SpinButton num_chooser_dialog_spin_button;
        [GtkChild]
        Gtk.Dialog str_chooser_dialog;
        [GtkChild]
        Gtk.Entry str_chooser_dialog_entry;
        [GtkChild]
        Gtk.Dialog type_chooser_dialog;
        [GtkChild]
        Gtk.Box type_chooser_rb_box;
        [GtkChild]
        Gtk.Revealer type_chooser_custom_type_rev;
        [GtkChild]
        Gtk.Entry type_chooser_custom_type_entry;
        [GtkChild]
        Gtk.SourceView python_view;
        [GtkChild]
        Gtk.Dialog python_code_dialog;
        // Render
        Gdk.RGBA color_cell;
        Gdk.RGBA color_text;
        Gdk.RGBA color_black;
        Gdk.RGBA color_editable;
        Gdk.RGBA color_cycle;
        Gdk.RGBA color_string;
        Gdk.RGBA color_object;
        Gdk.RGBA color_type_conversion;
        Gdk.RGBA color_comment;
        Pango.FontDescription font = new Pango.FontDescription();
        Pango.FontDescription small_font = new Pango.FontDescription();

        protected static string str_mark = ((char)31).to_string(); //Unit separator
        protected static string str_mark_utf8 = "~";
        public string resource_dir = "";

        public ProgramView () {
            // Props
            add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            add_events(Gdk.EventMask.KEY_PRESS_MASK);
            can_focus = true;
            // CSS
            var css_provider = new Gtk.CssProvider();
            var style_context = get_style_context();
            style_context.add_class("TurtlicoProgramView");
            css_provider.parsing_error.connect((s, e)=>{debug(e.message);});
            css_provider.load_from_resource("/com/orsan/Turtlico/programview.css");
            style_context.add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            // Render
            color_text.parse("rgb(255, 255, 255)");
            color_black.parse("rgb(0, 0, 0)");
            color_editable.parse("rgb(0, 0, 128)");
            color_cycle.parse("rgb(200, 0, 0)");
            color_string.parse("rgb(255, 220, 0)");
            color_object.parse("rgb(200, 200, 200)");
            color_type_conversion.parse("rgb(255, 140, 0)");
            color_comment.parse("rgb(255, 233, 140)");
            color_cell = style_context.get_color(Gtk.StateFlags.ACTIVE);
            font.set_weight(Pango.Weight.BOLD);
            font.set_size(15 * Pango.SCALE);
            small_font.set_family("Monospace");
            small_font.set_weight(Pango.Weight.THIN);
            small_font.set_size(9 * Pango.SCALE);
            // Widgets
            num_chooser_dialog_spin_button.activate.connect(()=>{num_chooser_dialog.hide();});
            str_chooser_dialog_entry.activate.connect(()=>{str_chooser_dialog.hide();});
            // DnD
            Gtk.drag_dest_set(
                this,                           // widget that will accept a drop
                Gtk.DestDefaults.ALL,           // default actions for dest on DnD
                target_list,                    // lists of target to support
                Gdk.DragAction.COPY
                | Gdk.DragAction.MOVE           // what to do with data after dropped
            );
            drag_data_received.connect(on_drag_data_received);
            drag_begin.connect(on_drag_begin);
            drag_data_get.connect(on_drag_data_get);
            drag_end.connect((context)=>{Gtk.drag_set_icon_default(context);});
            set_drag_source_active(true);

            // PythonView
            var language_manager = new Gtk.SourceLanguageManager();
            Gtk.SourceLanguage python_language = language_manager.get_language("python3");
            Gtk.SourceBuffer python_buffer = new Gtk.SourceBuffer.with_language(python_language);
            python_view.buffer = python_buffer;

            // Events
            motion_notify_event.connect((event)=>{
                mouse_x = (int)event.x;
                mouse_y = (int)event.y;
                if (selection_phase == SelectionPhase.SELECT_END) {
                    selection_end.y = int.min(mouse_y / cell_height, program.size - 1);
                    selection_end.x = int.min(
                        mouse_to_program_x(mouse_x / cell_width, selection_end.y),
                        program[selection_end.y].size - 1
                    );
                    queue_draw();
                }
                return false;
            });
            button_press_event.connect(on_button_press_event);
            button_release_event.connect(on_button_release_event);
            key_press_event.connect(on_key_press_event);

            // Tooltip
            query_tooltip.connect((x, y, keyboard_tooltip, tooltip)=>{
                if(!keyboard_tooltip){
                    // Get command pos
                    int cx = x / cell_width;
                    int cy = y / cell_height;
                    if (cy < program.size && cx < program[cy].size) {
                        // Command found
                        if (program[cy][cx].id == "tc" ||
                            program[cy][cx].id == "python")
                        {
                            tooltip.set_text(program[cy][cx].data);
                            return true;
                        }
                    }
                }
                return false;
            });
            has_tooltip = true;

            backup_program();
            program_changed = false;
        }

        void set_drag_source_active (bool active) {
            if (active) {
                Gtk.drag_source_set (
                    this,                          // widget will be drag-able
                    Gdk.ModifierType.BUTTON1_MASK, // modifier that will start a drag
                    target_list,                   // lists of target to support
                    Gdk.DragAction.MOVE            // what to do with data after dropped
                );
            }
            else {
                Gtk.drag_source_unset(this);
            }
        }

        void on_drag_data_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint info, uint time) {
            int length = selection_data.get_length();
            if(length > 0 && selection_data.get_format() == 8) {
                var data = new Gee.ArrayList<Gee.ArrayList<string>>();
                if(selection_data.get_text().has_prefix("file://")) {
                    try {
                        string path = selection_data.get_text().split("\r\n")[0];
                        File input = File.new_for_uri(path);
                        if (resource_dir == "") {
                            throw new FileError.ACCES(_("Please save the project first."));
                        }
                        File dest = File.new_for_path(
                            Path.build_filename(resource_dir, input.get_basename()));
                        if (!dest.query_exists())
                            input.copy(dest, FileCopyFlags.NONE);
                        data.add(new Gee.ArrayList<string>.wrap({"5_img", "./" + dest.get_basename()}));
                    }
                    catch (Error e) {
                        var dialog = new Gtk.MessageDialog((Gtk.Window)get_toplevel(),
                                                            Gtk.DialogFlags.MODAL,
                                                            Gtk.MessageType.ERROR,
                                                            Gtk.ButtonsType.OK, "");
                        dialog.text = _("Cannot insert the image");
                        dialog.secondary_text = e.message;
                        dialog.run(); dialog.destroy();
                        return;
                    }
                }
                else {
                    var commands = selection_data.get_text().split(str_mark_utf8);
                    foreach (var c in commands) {
                        debug(c);
                        data.add(new Gee.ArrayList<string>.wrap(c.split(";")));
                    }
                }
                y = y / cell_height;
                x = mouse_to_program_x(x / cell_width, y);
                for (int index = data.size - 1; index >= 0; index--) {
                    Gee.ArrayList<string> cmd = data[index];
                    if (cmd.size < 1) {
                        data.remove_at(index);
                        continue;
                    }
                    string id = cmd[0];
                    try {
                        Command c = find_command_by_id(id);
                        // Icon dropped under the last line
                        if (y >= program.size) {
                            var new_line = new Gee.ArrayList<Turtlico.Command>();
                            new_line.add(commands[0]);
                            y = program.size; program.add(new_line);
                            if (c.id == "nl") { program_changed = true; continue; }
                        }
                        // Icon dropped beyond the end of the line
                        if (x >= program[y].size) {
                            x = program[y].size;
                            if (program[y][program[y].size - 1].id == "nl") {
                                x--;
                            }
                        }
                        // Split lines
                        if (c.id == "nl") {
                            var new_line = new Gee.ArrayList<Turtlico.Command>();
                            new_line.add(commands[0]);
                            program.insert(y + 1, new_line);
                            // Get commands beyond the dropped new line
                            var beyond = new Gee.ArrayList<Command>.wrap(program[y].slice(x, program[y].size - 1).to_array());
                            program[y + 1].insert_all(0, beyond);
                            for (int i = 0; i < program[y + 1].size - 1; i++) {
                                program[y].remove_at(x);
                            }
                        }
                        else {
                            if (cmd.size >= 2)
                                c = c.set_data(cmd[1], resource_dir);
                            program[y].insert(x, c);
                        }
                        backup_program();
                        queue_draw();
                        Gtk.drag_finish(context, true, false, time);
                        if (c.id == "tc") {
                            icon_data_dialog_tc(x, y);
                        }
                        else if (c.id == "int") { c = c.set_data("0", resource_dir); }
                        continue;
                    }
                    catch (FileError e) {}
                }
                // Select inserted block
                if (data.size > 2) {
                    selection_start.x = x;
                    selection_start.y = y;
                    int n = 1;
                    while (n < data.size) {
                        x++;
                        if (x > program[y].size) {
                            y++;
                            x = 0;
                        }
                        n++;
                    }
                    selection_end.x = x;
                    selection_end.y = y;
                }
            }
            Gtk.drag_finish(context, false, false, time);
        }

        public override bool draw (Cairo.Context cr) {
            Gtk.Allocation allocation;
            get_allocation(out allocation);
            var style_context = get_style_context();

            // Background
            style_context.render_background(cr, allocation.x, allocation.y,
                                            allocation.width, allocation.height);
            // Foreground
            var state = style_context.get_state();
            color_cell = style_context.get_color(state);

            Gdk.Rectangle rect;
            Gdk.cairo_get_clip_rectangle(cr, out rect);
            int width = 0;
            int x;
            int original_x;
            bool selected = false;
            for (int line = 0; line < program.size; line++) {
                x = 0;
                for (int command = 0; command < program[line].size; command++) {
                    if (program[line][command].id == "int" && program[line][command].data == "") {
                        program[line][command] = program[line][command].set_data("0", resource_dir);
                    }
                    original_x = x;
                    if (line >= rect.y / cell_height && line <= (rect.y + rect.height) / cell_height) {
                        x += draw_icon(cr, x * cell_width, line * cell_height,
                                  program[line][command]);
                    }
                    else {
                        Command c = program[line][command];
                        if (c.id == "int" || c.id== "str" || c.id == "obj" || c.id == "#" || c.id == "5_img") {
                            x+=(c.data.length / 7 + 1);
                        }
                        else {x++;}
                    }
                    // Selection
                    bool on_selection_point = (line == selection_start.y && command == selection_start.x) ||
                        (line == selection_end.y && command == selection_end.x);
                    if (on_selection_point && !selected) {
                        selected = true;
                        on_selection_point = false;
                    }
                    if (selection_phase != SelectionPhase.NOTHING_SELECTED && selected)
                    {
                        cr.set_source_rgba(0, 0, 0, 0.5);
                        cr.rectangle(original_x * cell_width, line * cell_height,
                            cell_width * (x - original_x), cell_height);
                        cr.fill();
                    }
                    if (selected && selection_start.x == selection_end.x &&
                        selection_start.y == selection_end.y)
                        selected = false;
                    if (on_selection_point && selected)
                        selected = false;
                }
                if (x > width)
                    width = x;
            }
            set_size_request((width + 1) * cell_width,
                (program.size + 2) * cell_height);
            return true;
        }

        public int draw_icon (Cairo.Context cr, int x, int y, Command c) {
            // Size by the length of data
            int width = (c.data.length / 7 + 1);
            if (c.id == "python")
                width = 1;
            // Background
            if (c.id == "nl" || c.id == "tab")
                Gdk.cairo_set_source_rgba(cr, color_black);
            else if (c.id == "int")
                Gdk.cairo_set_source_rgba(cr, color_editable);
            else if (c.id == "str")
                Gdk.cairo_set_source_rgba(cr, color_string);
            else if (c.id == "obj")
                Gdk.cairo_set_source_rgba(cr, color_object);
            else if (c.id == "tc")
                Gdk.cairo_set_source_rgba(cr, color_type_conversion);
            else if (c.id == "#")
                Gdk.cairo_set_source_rgba(cr, color_comment);
            else if ((c.id.length > 0) && (c.id[0] == '1'))
                Gdk.cairo_set_source_rgba(cr, color_cycle);
            else
                Gdk.cairo_set_source_rgba(cr, color_cell);
            cr.rectangle(x, y, cell_width * width, cell_height);
            cr.fill();

            // Pixbuf icons
            if (c.pixbuf != null) {
                Gdk.cairo_set_source_pixbuf(cr, c.pixbuf,
                    x + cell_width / 2 - c.pixbuf.width / 2,
                    y + cell_height / 2 - c.pixbuf.height / 2);
                cr.paint();
                if (c.id != "5_img")
                    return 1;
            }

            // Emoji icons
            if(c.id.length > 0 && (c.id[0] == '3' || c.id[0] == '2'))
                Gdk.cairo_set_source_rgba(cr, color_editable);
            else
                Gdk.cairo_set_source_rgba(cr, color_text);
            // Type conversion command (draw data type)
            if (c.id == "tc") {
                Pango.Layout type_layout;
                if (c.data.length > 7) {
                    type_layout = create_pango_layout(c.data.substring(0, 4) + "...");
                }
                else {
                    type_layout = create_pango_layout(c.data);
                }
                cr.move_to(x, y + cell_height - 15);
                type_layout.set_alignment(Pango.Alignment.CENTER);
                type_layout.set_width(cell_width * Pango.SCALE);
                Pango.cairo_show_layout(cr, type_layout);
                type_layout.set_font_description(small_font);
                cr.move_to(x, y + 1);
            }
            else
                cr.move_to(x, y + 5);

            Pango.Layout layout;
            if (c.id == "int" || c.id== "str" || c.id == "obj" || c.id == "#" || c.id == "5_img") {
                layout = create_pango_layout(c.data);
                layout.set_font_description(small_font);
                if (c.id == "#" || c.id== "str" || c.id == "5_img")
                    Gdk.cairo_set_source_rgba(cr, color_black);
            }
            else {
                layout = create_pango_layout(c.name);
                layout.set_font_description(font);
            }
            layout.set_alignment(Pango.Alignment.CENTER);
            layout.set_width(cell_width * width * Pango.SCALE);
            layout.set_justify(false);
            Pango.cairo_show_layout(cr, layout);
            if (c.id == "int" || c.id== "str" || c.id == "obj" || c.id == "#" || c.id == "5_img")
                return width;
            else
                return 1;
        }

        void on_drag_begin(Gdk.DragContext context) {
            if (selection_phase == SelectionPhase.NOTHING_SELECTED) {
                int y = mouse_y / cell_height;
                int x = mouse_to_program_x(mouse_x / cell_width, y);
                if (!(y < program.size && x < program[y].size)) {
                    return;
                }
                selection_start.x = x; selection_end.x = x;
                selection_start.y = y; selection_end.y = y;
            }
            // Get height
            int height = (selection_end.y - selection_start.y + 1) * cell_height;
            int width;
            get_size_request(out width, null);
            // Draw commands
            var surface = new Cairo.ImageSurface(Cairo.Format.RGB24,
                width, height);
            var ctx = new Cairo.Context(surface);
            width = 0;
            int x = 0;
            int y = -1;
            selection_foreach((p)=>{
                if (p.y > y) {
                    x = 0;
                    y = p.y;
                }
                x += draw_icon(ctx, x * cell_width, (p.y - selection_start.y) * cell_height, program[p.y][p.x]);
                if (x > width)
                    width = x;
            });
            width = width * cell_width;
            debug("v");

            var pixbuf = Gdk.pixbuf_get_from_surface(surface, 0, 0,
                width, height);
            // Does not work when copying items
            // Gtk.drag_source_set_icon_pixbuf(this, pixbuf);
            Gtk.drag_set_icon_pixbuf(context, pixbuf, cell_width / 2, cell_height / 2);
        }

        void on_drag_data_get(Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time_) {
            int y = mouse_y / cell_height;
            int x = mouse_to_program_x(mouse_x / cell_width, y);
            if (y < program.size && x < program[y].size) {
                string data = "";
                selection_foreach((p)=>{
                    data += program[p.y][p.x].id + ";" + program[p.y][p.x].data + str_mark_utf8;
                });
                selection_data.set_text(data, -1);
                if (context.get_selected_action() == Gdk.DragAction.MOVE) {
                    if (program[y][x].id == "nl") {
                        // New line
                        if(y + 1 < program.size) {
                            program[y].add_all(program[y+1]);
                            program.remove_at(y + 1);
                            program[y].remove_at(x);
                        }
                        else if (program[y].size == 1) {
                            program.remove_at(y);
                        }
                    }
                    else {
                        // Anyting else
                        selection_delete();
                    }
                    backup_program();
                    queue_draw();
                }
            }
        }

        public override void size_allocate (Gtk.Allocation allocation) {
            base.size_allocate (allocation);
        }

        public Command find_command_by_id(string id) throws GLib.FileError {
            for (int i = 0; i < commands.size; i++) {
                if(commands[i].id == id) {
                    return commands[i];
                }
            }
            throw new GLib.FileError.FAILED("Command not found");
        }

        bool on_button_press_event(Gdk.EventButton event) {
            grab_focus();
            var modifiers = Gtk.accelerator_get_default_mod_mask();
            // Selection
            if (event.button == 1){
                if ((event.state & modifiers) == Gdk.ModifierType.SHIFT_MASK
                    && selection_phase == SelectionPhase.NOTHING_SELECTED)
                {
                    set_drag_source_active(false);
                    int y = mouse_y / cell_height;
                    int x = mouse_to_program_x(mouse_x / cell_width, y);
                    if(y < program.size && x < program[y].size) {
                        selection_phase = SelectionPhase.SELECT_END;
                        selection_start.x = x;
                        selection_start.y = y;
                    }
                }
                else {
                    selection_phase = SelectionPhase.NOTHING_SELECTED;
                    set_drag_source_active(true);
                    queue_draw();
                }
            }
            // Copy icon
            if (event.button == 3) {
                int y = mouse_y / cell_height;
                int x = mouse_to_program_x(mouse_x / cell_width, y);
                if(y < program.size && x < program[y].size) {
                    var targets = Gtk.drag_dest_get_target_list(this);
                    Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.COPY,
                       Gdk.ModifierType.BUTTON1_MASK, event, (int)event.x, (int)event.y);
                }
            }
            return false;
        }

        bool on_button_release_event(Gdk.EventButton event) {
            if (event.button == 1) {
                if (selection_phase == SelectionPhase.SELECT_END) {
                    selection_phase = SelectionPhase.BLOCK_SELECTED;
                    // Swap selection end and start if needed
                    bool do_swap = false;
                    if (selection_end.y < selection_start.y)
                        do_swap = true;
                    if (selection_end.y == selection_start.y && selection_start.x > selection_end.x)
                        do_swap = true;
                    if (do_swap) {
                        var end = selection_end;
                        selection_end = selection_start;
                        selection_start = end;
                    }
                }
            }
            return false;
        }

        bool on_key_press_event(Gdk.EventKey key_event) {
            var modifiers = Gtk.accelerator_get_default_mod_mask();

            if (key_event.keyval == Gdk.Key.Delete) {
                if (selection_phase == SelectionPhase.BLOCK_SELECTED) {
                    selection_delete();
                    backup_program();
                }
                else {
                    int y = mouse_y / cell_height;
                    int x = mouse_to_program_x(mouse_x / cell_width, y);
                    if(y < program.size && x < program[y].size) {
                        if(program[y][x].id != "nl") {
                            program[y].remove_at(x);
                            backup_program();
                        }
                    }
                }
                queue_draw();
            }
            if (key_event.keyval == Gdk.Key.z &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                undo();
            if (key_event.keyval == Gdk.Key.y &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                redo();
            if (key_event.keyval == Gdk.Key.F2) {
                int y = mouse_y / cell_height;
                if (y >= program.size)
                    return false;
                int x = mouse_to_program_x(mouse_x / cell_width, y);
                if (x < program[y].size) {
                    if (program[y][x].id == "int") {
                        num_chooser_dialog_spin_button.set_value(double.parse(program[y][x].data));
                        num_chooser_dialog_spin_button.grab_focus();

                        num_chooser_dialog.set_transient_for((Gtk.Window)get_toplevel());
                        num_chooser_dialog.run();
                        num_chooser_dialog.hide();
	                    string str = num_chooser_dialog_spin_button.get_text();
                        // Cut off 0s
                        int i = str.index_of(".");
                        if (i == -1)
                            i = str.index_of(",");
                        if (i > 0) {
                            int index = str.length ;
                            while (str[index - 1] == '0')
                                index--;
                            if (i + 1 == index)
                                index--;
                            var end = str.index_of_nth_char(index);
                            str = str.slice(0, end);
                        }
                        program[y][x] = program[y][x].set_data(str, resource_dir);
                        queue_draw();backup_program();
                    }
                    if (program[y][x].id == "str" || program[y][x].id == "obj"
                        || program[y][x].id == "#" || program[y][x].id == "5_img") {
                        str_chooser_dialog_entry.text = program[y][x].data;
                        str_chooser_dialog_entry.grab_focus();
                        if(program[y][x].id != "obj") {
                            str_chooser_dialog_entry.input_purpose = Gtk.InputPurpose.FREE_FORM;
                            #if TURTLICO_EMOJI_HINT
                            str_chooser_dialog_entry.input_hints = Gtk.InputHints.EMOJI;
                            #endif
                        }
                        else {
                            str_chooser_dialog_entry.input_purpose = Gtk.InputPurpose.ALPHA;
                            #if TURTLICO_EMOJI_HINT
                            str_chooser_dialog_entry.input_hints = Gtk.InputHints.NO_EMOJI;
                            #endif
                        }
                        str_chooser_dialog.set_transient_for((Gtk.Window)get_toplevel());
                        str_chooser_dialog.run();
                        str_chooser_dialog.hide();
                        program[y][x] = program[y][x].set_data(str_chooser_dialog_entry.text, resource_dir);
                        queue_draw();backup_program();
                    }
                    if (program[y][x].id == "tc") {
                        icon_data_dialog_tc(x, y);
                        queue_draw();backup_program();
                    }
                    if (program[y][x].id == "python") {
                        icon_data_dialog_python(x, y);
                        queue_draw();backup_program();
                    }
                }
            }
            return false;
        }

        void icon_data_dialog_tc (int x, int y) {
            type_chooser_dialog.set_transient_for((Gtk.Window)get_toplevel());
            type_chooser_dialog.run();
            type_chooser_dialog.hide();
            string type = "";
            var radio_buttons = type_chooser_rb_box.get_children();
            for (int i = 0; i < radio_buttons.length(); i++) {
                var rb = (Gtk.ToggleButton)radio_buttons.nth_data(i);
                if(rb.active) {
                    switch (i) {
                        case 0: type = "int"; break;
                        case 1: type = "float"; break;
                        case 2: type = "str"; break;
                        case 3: type = type_chooser_custom_type_entry.text; break;
                    }
                }
            }
            program[y][x] = program[y][x].set_data(type, resource_dir);
            queue_draw();
        }

        void icon_data_dialog_python(int x, int y) {
            python_code_dialog.set_transient_for((Gtk.Window)get_toplevel());
            python_view.buffer.text = program[y][x].data;
            python_code_dialog.run();
            python_code_dialog.hide();
            program[y][x] = program[y][x].set_data(python_view.buffer.text, resource_dir);
            queue_draw();
        }

        [GtkCallback]
        void on_rb_custom_toggled(Gtk.ToggleButton btn) {
            type_chooser_custom_type_rev.set_reveal_child(btn.active);
        }

        public void save_to_stream (OutputStream _ostream) throws IOError {
            var dostream = new DataOutputStream(_ostream);
            for(int y = 0; y < program.size; y++) {
                if (program[y].size == 0)
                    continue;
                for(int x = 0; x < program[y].size; x++) {
                    dostream.put_string(program[y][x].id + ",");
                    dostream.put_string(str_mark + program[y][x].data.replace("\n", "\\n") + str_mark + ",");
                    dostream.put_string(";");
                }
                dostream.put_string("\n");
            }
            foreach(string plugin in enabled_plugins) {
                dostream.put_string("plugin,");
                dostream.put_string(plugin + ",;");
            }
            program_changed = false;
        }

        public void load_from_stream (InputStream istream) throws IOError {
            load_from_stream_(istream, true);
            load_from_stream_(istream, false);
        }

        public void load_from_stream_ (InputStream istream, bool plugins_only) throws IOError {
            program.clear();
            enabled_plugins.clear();
            var distream = new DataInputStream(istream);
            size_t data_read = 0;
            string line = null;
            do {
                line = distream.read_line(out data_read);
                if (data_read == 0) continue;
                // Separate line into individual commands with data
                Gee.LinkedList<string> cmds = new Gee.LinkedList<string>();
                bool ingore = false;
                string tuple = "";
                for(int i = 0; i < line.length; i++){
                    if(line[i] == ';'){
                        if(!ingore){
                            cmds.add(tuple.replace("\\n", "\n"));
                            tuple = "";
                            continue;
                        }
                    }
                    else if(line[i] == str_mark[0]){
                        ingore = !ingore;
                    }
                    tuple = tuple + line[i].to_string();
                }
                // Parse
                program.add(new Gee.ArrayList<Turtlico.Command>());
                int y = program.size - 1;
                foreach (string cmd in cmds) {
                    // Properties (id, data)
                    Gee.LinkedList<string> props = new Gee.LinkedList<string>();
                    bool ignore = false;
                    string prop = "";
                    foreach (char c in cmd.to_utf8()) {
                        if (c == ',') {
                            props.add(prop);
                            prop = "";
                            continue;
                        }
                        else if (c == str_mark[0]) ingore = !ignore;
                        if (c != str_mark[0]) prop = prop + c.to_string();
                    }
                    // Plugins
                    if (props[0] == "plugin") {
                        if (!enabled_plugins.contains(props[1]))
                            enabled_plugins.add(props[1]);
                        continue;
                    }
                    else if (plugins_only) {
                        continue;
                    }
                    // Add command
                    if (props.size < 2){
                         var dialog = new Gtk.MessageDialog((Gtk.Window)get_toplevel(),
                                                            Gtk.DialogFlags.MODAL,
                                                            Gtk.MessageType.ERROR,
                                                            Gtk.ButtonsType.OK, "");
                        dialog.text = _("Failed to open the file. Error on line: " + y.to_string());
                        dialog.run(); dialog.destroy();
                    }
                    try {
                        Command c = find_command_by_id(props[0]);
                        // Set data only if necessary
                        if (props[1] != "") c = c.set_data(props[1], resource_dir);

                        program[y].add(c);
                    }
                    catch (FileError e) {
                         var dialog = new Gtk.MessageDialog((Gtk.Window)get_toplevel(),
                                                            Gtk.DialogFlags.MODAL,
                                                            Gtk.MessageType.ERROR,
                                                            Gtk.ButtonsType.OK, "");
                        dialog.text = _("The file to load contains an unkown command!");
                        dialog.secondary_text =
                            _("This might be because of the file was damaged or created by a newer version of this program.\nCommand ID: ") + props[0];
                        dialog.run(); dialog.destroy();
                    }
                }
                if (program[y].size == 0) {program.remove_at(y);}

            }  while (line != null);
            queue_draw();
            // History
            history.clear();
            history_index = 0;
            backup_program();
            program_changed = false;
        }

        public void undo () {
            if (history.size - history_index - 2 < 0)
                return;
            var h = history[history.size - history_index - 2];
            copy_list(h, ref program);
            queue_draw();
            history_index++;
        }

        public void redo() {
            if (history_index == 0)
                return;
            history_index--;
            var h = history[history.size - history_index - 1];
            copy_list(h, ref program);
            queue_draw();
        }

        public void backup_program () {
            program_changed = true;
            if (history_index > 0) {
                for (int i = history.size - history_index; i < history.size; i++)
                    history.remove_at(i);
            }
            history_index = 0;
            var undo = new ArrayList<ArrayList<Command>>();
            copy_list(program, ref undo);
            history.add(undo);
            while (history.size > history_buffer_size)
                history.remove_at(0);
        }

        public void backup_clear (bool save_current_state = true) {
            history.clear();
            history_index = 0;
            if (save_current_state)
                backup_program();
        }

        void copy_list(ArrayList<ArrayList<Command>> l1,
            ref ArrayList<ArrayList<Command>> l2)
        {
            l2.clear();
            foreach (var line in l1) {
                var l = new ArrayList<Command>();
                foreach (var icon in line) {
                    l.add(icon);
                }
                l2.add(l);
            }
        }

        int mouse_to_program_x (int x, int y) {
            if (program.size == 0 || y >= program.size)
                return x;
            int result = 0;
            int i = 0;
            while (i < x && result < program[y].size) {
                for (int iterator = 0;
                    iterator < (program[y][result].data.length / 7) && i < x && result < program[y].size;
                    iterator++)
                {
                    i++;
                }
                if (i >= x) break;
                result++;
                i++;
            }
            if (result < 0) result = 0;
            return result;
        }

        void selection_foreach (Func<Gdk.Point?> func) {
            for (int line = selection_start.y; line <= selection_end.y; line++) {
                for (int command = 0; command < program[line].size; command++) {
                    if (line == selection_start.y && command < selection_start.x)
                        continue;
                    if (line == selection_end.y && command > selection_end.x)
                        return;
                    Gdk.Point point = Gdk.Point();
                    point.x = command;
                    point.y = line;
                    func(point);
                }
            }
        }

        void selection_delete () {
            for (int line = selection_start.y; line <= selection_end.y; line++) {
                for (int command = 0; command < program[line].size; command++) {
                    if (line == selection_start.y && command < selection_start.x)
                        continue;
                    if (line == selection_end.y && command > selection_end.x)
                        continue;
                    if (program[line][command].id == "nl" && program[line].size > 1)
                        continue;
                    program[line].remove_at(command);
                    command--;
                    if (line == selection_end.y)
                        selection_end.x--;
                }
            }
            fix_blank_lines();

            selection_phase = SelectionPhase.NOTHING_SELECTED;
        }

        void fix_blank_lines () {
            for (int line = 0; line < program.size; line++) {
                if (program[line].size == 0) {
                    program.remove_at(line);
                    line--;
                }
            }
        }
    }
}
