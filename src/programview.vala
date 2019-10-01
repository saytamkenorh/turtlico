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

    [GtkTemplate (ui = "/com/orsan/Turtlico/programview.ui")]
    public class ProgramView : Gtk.DrawingArea {
        public const int cell_width = 50;
        public const int cell_height = 35;
        public ProgramBuffer buffer {
            get {
                return _buffer;
            }
            set {
                _buffer = value;
                queue_draw();
                _buffer.redraw_required.connect(queue_draw);
            }
        }
        private ProgramBuffer _buffer;
        private bool drag_source_clipboard = false;
        private string drag_source_clipboard_text = "";
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
        [GtkChild]
        Gtk.FontChooserDialog font_dialog;
        [GtkChild]
        Gtk.ColorChooserDialog color_dialog;
        [GtkChild]
        Gtk.Dialog key_dialog;
        [GtkChild]
        Gtk.Label key_dialog_label;
        // Render
        Pango.FontDescription font = new Pango.FontDescription();
        Pango.FontDescription small_font = new Pango.FontDescription();

        public ProgramView () {
            // Props
            add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            add_events(Gdk.EventMask.KEY_PRESS_MASK);
            can_focus = true;
            buffer = new ProgramBuffer();
            // CSS
            var css_provider = new Gtk.CssProvider();
            var style_context = get_style_context();
            style_context.add_class("TurtlicoProgramView");
            css_provider.parsing_error.connect((s, e)=>{debug(e.message);});
            css_provider.load_from_resource("/com/orsan/Turtlico/programview.css");
            style_context.add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            // Render
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
            drag_end.connect((context)=>{Gtk.drag_set_icon_default(context); drag_source_clipboard = false;});
            set_drag_source_active(true);

            // PythonView
            var language_manager = new Gtk.SourceLanguageManager();
            Gtk.SourceLanguage python_language = language_manager.get_language("python3");
            Gtk.SourceBuffer python_buffer = new Gtk.SourceBuffer.with_language(python_language);
            python_view.buffer = python_buffer;

            // Events
            motion_notify_event.connect((event)=>{
                mouse_x = (int)event.x;
                mouse_y = int.max((int)event.y, 0);
                if (buffer.selection_phase == SelectionPhase.SELECT_END) {
                    buffer.selection_end.y = int.min(mouse_y / cell_height, buffer.program.size - 1);
                    buffer.selection_end.x = int.min(
                        mouse_to_program_x(mouse_x / cell_width, buffer.selection_end.y),
                        buffer.program[buffer.selection_end.y].size - 1
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
                    if (cy < buffer.program.size && cx < buffer.program[cy].size) {
                        // Command found
                        if (buffer.program[cy][cx].id == "tc" ||
                            buffer.program[cy][cx].id == "python")
                        {
                            tooltip.set_text(buffer.program[cy][cx].data);
                            return true;
                        }
                    }
                }
                return false;
            });
            has_tooltip = true;

            buffer.backup_program();
            buffer.program_changed = false;
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
            mouse_x = x;
            mouse_y = y;
            int length = selection_data.get_length();
            if(length > 0 && selection_data.get_format() == 8) {
                var data = new Gee.ArrayList<Gee.ArrayList<string>>();
                if(selection_data.get_text().has_prefix("file://")) {
                    try {
                        string path = selection_data.get_text().split("\r\n")[0];
                        File input = File.new_for_uri(path);
                        if (buffer.resource_dir == "") {
                            throw new FileError.ACCES(_("Please save the project first."));
                        }
                        File dest = File.new_for_path(
                            Path.build_filename(buffer.resource_dir, input.get_basename()));
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
                    var commands = selection_data.get_text().split(ProgramBuffer.str_mark_utf8);
                    foreach (var c in commands) {
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
                        Command c = buffer.find_command_by_id(id);
                        // Icon dropped under the last line
                        if (y >= buffer.program.size) {
                            var new_line = new Gee.ArrayList<Turtlico.Command>();
                            new_line.add(buffer.commands[0]);
                            y = buffer.program.size; buffer.program.add(new_line);
                            if (c.id == "nl") { buffer.program_changed = true; continue; }
                        }
                        // Icon dropped beyond the end of the line
                        if (x >= buffer.program[y].size) {
                            x = buffer.program[y].size;
                            if (buffer.program[y][buffer.program[y].size - 1].id == "nl") {
                                x--;
                            }
                        }
                        // Split lines
                        if (c.id == "nl") {
                            var new_line = new Gee.ArrayList<Turtlico.Command>();
                            new_line.add(buffer.commands[0]);
                            buffer.program.insert(y + 1, new_line);
                            // Get commands beyond the dropped new line
                            var beyond = new Gee.ArrayList<Command>.wrap(buffer.program[y].slice(x, buffer.program[y].size - 1).to_array());
                            buffer.program[y + 1].insert_all(0, beyond);
                            for (int i = 0; i < buffer.program[y + 1].size - 1; i++) {
                                buffer.program[y].remove_at(x);
                            }
                        }
                        else {
                            if (cmd.size >= 2)
                                c = c.set_data(cmd[1], buffer.resource_dir);
                            buffer.program[y].insert(x, c);
                        }
                        buffer.backup_program();
                        queue_draw();
                        Gtk.drag_finish(context, true, false, time);
                        if (c.id == "tc") {
                            icon_data_dialog_tc(x, y);
                        }
                        else if (c.id == "int") { c = c.set_data("0", buffer.resource_dir); }
                        continue;
                    }
                    catch (FileError e) {}
                }
                buffer.selection_phase = SelectionPhase.NOTHING_SELECTED;
                set_drag_source_active(true);
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
            Gdk.Rectangle rect;
            Gdk.cairo_get_clip_rectangle(cr, out rect);
            int width = 0;
            int x;
            int original_x;
            bool selected = false;
            for (int line = 0; line < buffer.program.size; line++) {
                x = 0;
                for (int command = 0; command < buffer.program[line].size; command++) {
                    if (buffer.program[line][command].id == "int" && buffer.program[line][command].data == "") {
                        buffer.program[line][command] = buffer.program[line][command].set_data("0", buffer.resource_dir);
                    }
                    original_x = x;
                    if (line >= rect.y / cell_height && line <= (rect.y + rect.height) / cell_height) {
                        x += draw_icon(cr, x * cell_width, line * cell_height,
                                  buffer.program[line][command]);
                    }
                    else {
                        Command c = buffer.program[line][command];
                        if (c.id == "int" || c.id== "str" || c.id == "obj" || c.id == "#" || c.id == "5_img" || c.id == "4_font") {
                            x+=(c.data.length / 7 + 1);
                        }
                        else {x++;}
                    }
                    // Selection
                    bool on_selection_point = (line == buffer.selection_start.y && command == buffer.selection_start.x) ||
                        (line == buffer.selection_end.y && command == buffer.selection_end.x);
                    if (on_selection_point && !selected) {
                        selected = true;
                        on_selection_point = false;
                    }
                    if (buffer.selection_phase != SelectionPhase.NOTHING_SELECTED && selected)
                    {
                        cr.set_source_rgba(0, 0, 0, 0.5);
                        cr.rectangle(original_x * cell_width, line * cell_height,
                            cell_width * (x - original_x), cell_height);
                        cr.fill();
                    }
                    if (selected && buffer.selection_start.x == buffer.selection_end.x &&
                        buffer.selection_start.y == buffer.selection_end.y)
                        selected = false;
                    if (on_selection_point && selected)
                        selected = false;
                }
                if (x > width)
                    width = x;
            }
            set_size_request((width + 1) * cell_width,
                (buffer.program.size + 2) * cell_height);
            return true;
        }

        public int draw_icon (Cairo.Context cr, int x, int y, Command c) {
            // Size by the length of data
            int width = (c.data.length / 7 + 1);
            if (c.id == "python" || c.id == "4_color")
                width = 1;
            // Background
            Gdk.cairo_set_source_rgba(cr, c.draw_params.bg_color);
            cr.rectangle(x, y, cell_width * width, cell_height);
            cr.fill();

            // Pixbuf icons
            if (c.pixbuf != null) {
                Gdk.cairo_set_source_pixbuf(cr, c.pixbuf,
                    x + cell_width * width / 2 - c.pixbuf.width / 2,
                    y + cell_height / 2 - c.pixbuf.height / 2);
                cr.paint();
                if (!c.draw_params.data_draw)
                    return 1;
            }

            cr.move_to(x, y + 5); // Center of the icon
            Gdk.cairo_set_source_rgba(cr, c.draw_params.fg_color); // Foreground color

            // Draw emoji icon
            if (!c.name.has_suffix(".png")) {
                if (c.data == "" || (c.draw_params.data_draw && !c.draw_params.data_only) || c.id == "4_color") {
                    string text;
                    if (c.id == "4_color" && c.data != "") {
                        text = "⬤";
                        Gdk.RGBA color = Gdk.RGBA();
                        color.parse(c.data);
                        Gdk.cairo_set_source_rgba(cr, color);
                    }
                    else text = c.name;
                    var layout = draw_icon_new_layout(text, font, width);
                    Pango.cairo_show_layout(cr, layout);
                }
            }
            // Draw data
            if (c.draw_params.data_draw && c.data != "") {
                if (!c.draw_params.data_only)
                    cr.move_to(x, y + cell_height - 15); // Draw data under the icon if we draw both
                Pango.Layout data_layout = draw_icon_new_layout(c.data, small_font, width);
                Gdk.cairo_set_source_rgba(cr, c.draw_params.data_color);
                Pango.cairo_show_layout(cr, data_layout);
            }
            if (c.draw_params.data_draw)
                return width;
            else
                return 1;
        }

        Pango.Layout draw_icon_new_layout (string text, Pango.FontDescription font, int icon_width) {
            Pango.Layout layout = create_pango_layout(text);
            layout.set_font_description(font);
            layout.set_alignment(Pango.Alignment.CENTER);
            layout.set_width(cell_width * icon_width * Pango.SCALE);
            layout.set_justify(false);
            return layout;
        }

        void on_drag_begin(Gdk.DragContext context) {
            if (drag_source_clipboard) {
                int width = 0;
                int height = 1;

                var data = new Gee.ArrayList<Gee.ArrayList<string>>();
                var commands = drag_source_clipboard_text.split(ProgramBuffer.str_mark_utf8);
                foreach (var c in commands) {
                    data.add(new Gee.ArrayList<string>.wrap(c.split(";")));
                }

                var surface = new Cairo.ImageSurface(Cairo.Format.RGB24,
                    data.size * cell_width, data.size * cell_height);
                var ctx = new Cairo.Context(surface);
                int x = 0;
                for (int i = 0; i < data.size; i++) {
                    if (data[i].size == 0)
                        continue;
                    if (i > 0 && data[i - 1][0] == "nl") {
                        x = 0;
                        height++;
                    }
                    try {
                        Command c = buffer.find_command_by_id(data[i][0]);
                        if(data[i].size >= 2)
                            c = c.set_data(data[i][1], buffer.resource_dir);
                        x += draw_icon(ctx, x * cell_width, (height - 1) * cell_height, c);
                        if (x > width)
                            width = x;
                    }
                    catch {}
                }
                if (!(width > 0 && height > 0))
                    return;
                var pixbuf = Gdk.pixbuf_get_from_surface(surface, 0, 0,
                    width * cell_width, height * cell_height);
                Gtk.drag_set_icon_pixbuf(context, pixbuf, cell_width / 2, cell_height / 2);
                return;
            }
            if (buffer.selection_phase == SelectionPhase.NOTHING_SELECTED) {
                int y = mouse_y / cell_height;
                int x = mouse_to_program_x(mouse_x / cell_width, y);
                if (!(y < buffer.program.size && x < buffer.program[y].size)) {
                    return;
                }
                buffer.selection_start.x = x; buffer.selection_end.x = x;
                buffer.selection_start.y = y; buffer.selection_end.y = y;
            }
            // Get height
            int height = (buffer.selection_end.y - buffer.selection_start.y + 1) * cell_height;
            int width;
            get_size_request(out width, null);
            // Draw commands
            var surface = new Cairo.ImageSurface(Cairo.Format.RGB24,
                width, height);
            var ctx = new Cairo.Context(surface);
            width = 0;
            int x = 0;
            int y = -1;
            buffer.selection_foreach((p)=>{
                if (p.y > y) {
                    x = 0;
                    y = p.y;
                }
                x += draw_icon(ctx, x * cell_width, (p.y - buffer.selection_start.y) * cell_height, buffer.program[p.y][p.x]);
                if (x > width)
                    width = x;
            });
            width = width * cell_width;

            var pixbuf = Gdk.pixbuf_get_from_surface(surface, 0, 0,
                width, height);
            // Does not work when copying items
            // Gtk.drag_source_set_icon_pixbuf(this, pixbuf);
            Gtk.drag_set_icon_pixbuf(context, pixbuf, cell_width / 2, cell_height / 2);
        }

        void on_drag_data_get(Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time_) {
            if (drag_source_clipboard) {
                selection_data.set_text(drag_source_clipboard_text, -1);
                return;
            }
            int y = mouse_y / cell_height;
            int x = mouse_to_program_x(mouse_x / cell_width, y);
            if (y < buffer.program.size && x < buffer.program[y].size) {
                int command_count;
                string data = buffer.selection_to_string(out command_count);
                selection_data.set_text(data, -1);
                if (context.get_selected_action() == Gdk.DragAction.MOVE) {
                    if (buffer.program[y][x].id == "nl" && command_count == 1) {
                        // New line
                        if(y + 1 < buffer.program.size) {
                            buffer.program[y].add_all(buffer.program[y+1]);
                            buffer.program.remove_at(y + 1);
                            buffer.program[y].remove_at(x);
                        }
                        else if (buffer.program[y].size == 1) {
                            buffer.program.remove_at(y);
                        }
                    }
                    else {
                        // Anyting else
                        buffer.selection_delete();
                    }
                    buffer.selection_phase = SelectionPhase.NOTHING_SELECTED;
                    set_drag_source_active(true);
                    buffer.backup_program();
                    queue_draw();
                }
            }
        }

        public override void size_allocate (Gtk.Allocation allocation) {
            base.size_allocate (allocation);
        }

        bool on_button_press_event(Gdk.EventButton event) {
            grab_focus();
            var modifiers = Gtk.accelerator_get_default_mod_mask();
            // Selection
            if (event.button == 1) {
                if ((event.state & modifiers) == Gdk.ModifierType.SHIFT_MASK
                    && buffer.selection_phase == SelectionPhase.NOTHING_SELECTED)
                {
                    int y = mouse_y / cell_height;
                    int x = mouse_to_program_x(mouse_x / cell_width, y);
                    if(y < buffer.program.size && x < buffer.program[y].size) {
                        set_drag_source_active(false);
                        buffer.selection_phase = SelectionPhase.SELECT_END;
                        buffer.selection_start.x = x;
                        buffer.selection_start.y = y;
                    }
                }
                else if (buffer.selection_phase == SelectionPhase.BLOCK_SELECTED) {
                    int y = mouse_y / cell_height;
                    int x = mouse_to_program_x(mouse_x / cell_width, y);
                    if (y < buffer.program.size && x < buffer.program[y].size) {
                        var targets = Gtk.drag_dest_get_target_list(this);
                        Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.MOVE,
                           Gdk.ModifierType.BUTTON1_MASK, event, (int)event.x, (int)event.y);
                    }
                    else {
                        buffer.selection_phase = SelectionPhase.NOTHING_SELECTED;
                        set_drag_source_active(true);
                        queue_draw();
                    }
                }
                else {
                    var targets = Gtk.drag_dest_get_target_list(this);
                    int y = mouse_y / cell_height;
                    int x = mouse_to_program_x(mouse_x / cell_width, y);
                    if (y < buffer.program.size && x < buffer.program[y].size) {
                        set_drag_source_active(true);
                        Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.MOVE,
                               Gdk.ModifierType.BUTTON1_MASK, event, (int)event.x, (int)event.y);
                    }
                    else {
                        buffer.selection_phase = SelectionPhase.NOTHING_SELECTED;
                        set_drag_source_active(false);
                    }
                    queue_draw();
                }
            }
            // Copy icon
            if (event.button == 3) {
                int y = mouse_y / cell_height;
                int x = mouse_to_program_x(mouse_x / cell_width, y);
                if(y < buffer.program.size && x < buffer.program[y].size) {
                    var targets = Gtk.drag_dest_get_target_list(this);
                    Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.COPY,
                       Gdk.ModifierType.BUTTON3_MASK, event, (int)event.x, (int)event.y);
                }
            }
            return false;
        }

        bool on_button_release_event(Gdk.EventButton event) {
            if (event.button == 1) {
                if (buffer.selection_phase == SelectionPhase.SELECT_END) {
                    buffer.selection_phase = SelectionPhase.BLOCK_SELECTED;
                    // Swap selection end and start if needed
                    bool do_swap = false;
                    if (buffer.selection_end.y < buffer.selection_start.y)
                        do_swap = true;
                    if (buffer.selection_end.y == buffer.selection_start.y && buffer.selection_start.x > buffer.selection_end.x)
                        do_swap = true;
                    if (do_swap) {
                        var end = buffer.selection_end;
                        buffer.selection_end = buffer.selection_start;
                        buffer.selection_start = end;
                    }
                }
            }
            return false;
        }

        bool on_key_press_event(Gdk.EventKey key_event) {
            var modifiers = Gtk.accelerator_get_default_mod_mask();

            if (key_event.keyval == Gdk.Key.Delete) {
                if (buffer.selection_phase == SelectionPhase.BLOCK_SELECTED) {
                    buffer.selection_delete();
                    buffer.backup_program();
                }
                else {
                    int y = mouse_y / cell_height;
                    int x = mouse_to_program_x(mouse_x / cell_width, y);
                    if(y < buffer.program.size && x < buffer.program[y].size) {
                        if(buffer.program[y][x].id != "nl") {
                            buffer.program[y].remove_at(x);
                            buffer.backup_program();
                        }
                    }
                }
                queue_draw();
            }
            if (key_event.keyval == Gdk.Key.z &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                buffer.undo();
            if (key_event.keyval == Gdk.Key.y &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                buffer.redo();
            if (key_event.keyval == Gdk.Key.F2) {
                int y = mouse_y / cell_height;
                if (y >= buffer.program.size)
                    return false;
                int x = mouse_to_program_x(mouse_x / cell_width, y);
                if (x < buffer.program[y].size) {
                    if (buffer.program[y][x].id == "int") {
                        num_chooser_dialog_spin_button.set_value(double.parse(buffer.program[y][x].data));
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
                        buffer.program[y][x] = buffer.program[y][x].set_data(str, buffer.resource_dir);
                        queue_draw();buffer.backup_program();
                    }
                    if (buffer.program[y][x].id == "str" || buffer.program[y][x].id == "obj"
                        || buffer.program[y][x].id == "#" || buffer.program[y][x].id == "5_img") {
                        str_chooser_dialog_entry.text = buffer.program[y][x].data;
                        str_chooser_dialog_entry.grab_focus();
                        if(buffer.program[y][x].id != "obj") {
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
                        buffer.program[y][x] = buffer.program[y][x].set_data(str_chooser_dialog_entry.text, buffer.resource_dir);
                        queue_draw();buffer.backup_program();
                    }
                    if (buffer.program[y][x].id == "tc") {
                        icon_data_dialog_tc(x, y);
                        queue_draw();buffer.backup_program();
                    }
                    if (buffer.program[y][x].id == "python") {
                        icon_data_dialog_python(x, y);
                        queue_draw();buffer.backup_program();
                    }
                    if (buffer.program[y][x].id == "4_color") {
                        icon_data_dialog_color(x, y);
                        queue_draw();buffer.backup_program();
                    }
                    if (buffer.program[y][x].id == "4_font") {
                        icon_data_dialog_font(x, y);
                        queue_draw();buffer.backup_program();
                    }
                    if (buffer.program[y][x].id == "key") {
                        icon_data_dialog_key(x, y);
                        queue_draw();buffer.backup_program();
                    }
                }
            }
            if ((key_event.keyval == Gdk.Key.c || key_event.keyval == Gdk.Key.x) &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK &&
                buffer.selection_phase == SelectionPhase.BLOCK_SELECTED)
            {
                var clipboard = get_clipboard(Gdk.SELECTION_CLIPBOARD);
                int command_count;
                clipboard.set_text(buffer.selection_to_string(out command_count), -1);
                if (key_event.keyval == Gdk.Key.x) {
                    buffer.selection_delete();
                    buffer.backup_program();
                }
            }
            if (key_event.keyval == Gdk.Key.v &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
            {
                var clipboard = get_clipboard(Gdk.SELECTION_CLIPBOARD);
                string data = clipboard.wait_for_text();
                if (data == null || !data.contains(";"))
                    return false;
                buffer.selection_phase = SelectionPhase.NOTHING_SELECTED;
                var targets = Gtk.drag_dest_get_target_list(this);
                drag_source_clipboard = true;
                drag_source_clipboard_text = data;
                Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.COPY,
                               Gdk.ModifierType.BUTTON1_MASK, key_event, -1, -1);
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
            buffer.program[y][x] = buffer.program[y][x].set_data(type, buffer.resource_dir);
            queue_draw();
        }

        [GtkCallback]
        void on_rb_custom_toggled(Gtk.ToggleButton btn) {
            type_chooser_custom_type_rev.set_reveal_child(btn.active);
        }

        void icon_data_dialog_python(int x, int y) {
            python_code_dialog.set_transient_for((Gtk.Window)get_toplevel());
            python_view.buffer.text = buffer.program[y][x].data;
            python_code_dialog.run();
            python_code_dialog.hide();
            buffer.program[y][x] = buffer.program[y][x].set_data(python_view.buffer.text, buffer.resource_dir);
            queue_draw();
        }

        void icon_data_dialog_color(int x, int y) {
            color_dialog.set_transient_for((Gtk.Window)get_toplevel());
            color_dialog.run();
            color_dialog.hide();
            buffer.program[y][x] = buffer.program[y][x].set_data(color_dialog.rgba.to_string(), buffer.resource_dir);
            queue_draw();
        }

        void icon_data_dialog_font(int x, int y) {
            font_dialog.set_transient_for((Gtk.Window)get_toplevel());
            if (buffer.program[y][x].data != "") {
                var description = new Pango.FontDescription();
                var items = buffer.program[y][x].data.split(";");
                description.set_family(items[0]);
                description.set_size(int.parse(items[1]) * Pango.SCALE);
                switch(items[2]) {
                    case "italic":
                        description.set_style(Pango.Style.ITALIC); break;
                    case "normal":
                        description.set_style(Pango.Style.NORMAL); break;
                }
                if(items[3] == "bold")
                    description.set_weight(Pango.Weight.BOLD);
                font_dialog.font_desc = description;
            }
            font_dialog.run();
            font_dialog.hide();
            var font_desc = font_dialog.font_desc;
            string data = font_desc.get_family() + ";" +
                (font_desc.get_size() / Pango.SCALE).to_string() + ";";
            switch(font_desc.get_style()) {
                case Pango.Style.ITALIC:
                    data += "italic"; break;
                case Pango.Style.NORMAL:
                    data += "normal"; break;
            }
            if (font_desc.get_weight() == Pango.Weight.BOLD)
                data += ";bold";
            else
                data += ";normal";
            buffer.program[y][x] = buffer.program[y][x].set_data(data, buffer.resource_dir);
            queue_draw();
        }

        void icon_data_dialog_key(int x, int y) {
            key_dialog.set_transient_for((Gtk.Window)get_toplevel());
            key_dialog_label.label = buffer.program[y][x].data;
            key_dialog.run();
            key_dialog.hide();
            buffer.program[y][x] = buffer.program[y][x].set_data(key_dialog_label.label, buffer.resource_dir);
        }

        [GtkCallback]
        bool on_key_dialog_key_press_event(Gdk.EventKey key_event) {
            if (key_event.keyval == Gdk.Key.ISO_Level3_Shift) key_dialog_label.label = "Alt_R";
            else key_dialog_label.label = Gdk.keyval_name(key_event.keyval);
            return false;
        }

        int mouse_to_program_x (int x, int y) {
            if (buffer.program.size == 0 || y >= buffer.program.size)
                return x;
            int result = 0;
            int i = 0;
            while (i < x && result < buffer.program[y].size) {
                if (buffer.program[y][result].id != "python" && buffer.program[y][result].id != "4_color") {
                    for (int iterator = 0;
                        iterator < (buffer.program[y][result].data.length / 7) && i < x && result < buffer.program[y].size;
                        iterator++)
                    {
                        i++;
                    }
                }
                if (i >= x) break;
                result++;
                i++;
            }
            if (result < 0) result = 0;
            return result;
        }
    }
}
