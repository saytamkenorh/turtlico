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

    [GtkTemplate (ui = "/tk/turtlico/Turtlico/programview.ui")]
    public class ProgramView : Gtk.DrawingArea {
        public const int cell_width = 50;
        public const int cell_height = 35;
        public ProgramBuffer buffer {
            get {
                return _buffer;
            }
            set {
                if (_buffer is ProgramBuffer) {
                    _buffer.redraw_required.disconnect(queue_draw);
                    _buffer.scroll_to_selection.disconnect(scroll_to_selection);
                }
                _buffer = value;
                queue_draw();
                _buffer.redraw_required.connect(queue_draw);
                _buffer.scroll_to_selection.connect(scroll_to_selection);
            }
        }
        private ProgramBuffer _buffer;
        private bool drag_source_clipboard = false;
        private string drag_source_clipboard_text = "";
        public bool high_contrast = false;
        public bool auto_indent = true;
        public bool basic_mode = false;
        //DnD
        bool start_dnd_copy = false;
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
        [GtkChild]
        Gtk.Menu popup_menu_widget;
        [GtkChild]
        Gtk.MenuItem popup_menu_edit;
        [GtkChild]
        Gtk.MenuItem popup_menu_copy;
        [GtkChild]
        Gtk.MenuItem popup_menu_cut;
        [GtkChild]
        Gtk.SeparatorMenuItem popup_menu_sep;
        [GtkChild]
        Gtk.MenuItem popup_menu_comment;
        [GtkChild]
        Gtk.MenuItem popup_menu_uncomment;
        // Render
        Pango.FontDescription font = new Pango.FontDescription();
        Pango.FontDescription small_font = new Pango.FontDescription();
        Gdk.RGBA color_high_contrast_cell;
        Gdk.RGBA color_black;

        public ProgramView () {
            // Props
            add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            add_events(Gdk.EventMask.KEY_PRESS_MASK);
            can_focus = true;
            buffer = new ProgramBuffer();
            buffer.save_history = !basic_mode;
            // CSS
            var css_provider = new Gtk.CssProvider();
            var style_context = get_style_context();
            style_context.add_class("TurtlicoProgramView");
            css_provider.parsing_error.connect((s, e)=>{debug(e.message);});
            css_provider.load_from_resource("/tk/turtlico/Turtlico/programview.css");
            style_context.add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            // Render
            font.set_weight(Pango.Weight.BOLD);
            font.set_size(15 * Pango.SCALE);
            small_font.set_family("Monospace");
            small_font.set_weight(Pango.Weight.THIN);
            small_font.set_size(9 * Pango.SCALE);
            color_high_contrast_cell.parse("rgb(50,50,50)");
            color_black.parse("rgb(0,0,0)");
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
            drag_end.connect((context)=>{drag_source_clipboard = false;});
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
                if (start_dnd_copy) {
                    var targets = Gtk.drag_dest_get_target_list(this);
                    Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.COPY,
                       Gdk.ModifierType.BUTTON3_MASK, event, (int)event.x, (int)event.y);
                    start_dnd_copy = false;
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
            bool success = false;

            if(length > 0 && selection_data.get_format() == 8) {
                y = y / cell_height;
                x = mouse_to_program_x(x / cell_width, y);
                try {
                    success = buffer.paste_icons_string(selection_data.get_text(), ref x, ref y, basic_mode, auto_indent);
                    if (selection_data.get_text() == "tc") {
                        icon_data_dialog_tc(x, y);
                    }
                }
                catch (Error e) {
                    var dialog = new Gtk.MessageDialog((Gtk.Window)get_toplevel(),
                                        Gtk.DialogFlags.MODAL,
                                        Gtk.MessageType.ERROR,
                                        Gtk.ButtonsType.OK, "");
                    dialog.text = e.message;
                    dialog.run(); dialog.destroy();
                }
                set_drag_source_active(true);
            }
            Gtk.drag_finish(context, success, false, time);
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
            bool comment = false;
            for (int line = 0; line < buffer.program.size; line++) {
                x = 0;
                comment = false;
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
                    // Comments
                    if (buffer.program[line][command].id == "nl")
                        comment = false;
                    if (comment) {
                        cr.set_source_rgba(0, 0, 0, 0.5);
                        cr.rectangle(original_x * cell_width, line * cell_height,
                            cell_width * (x - original_x), cell_height);
                        cr.fill();
                    }
                    if (buffer.program[line][command].id == "#" && buffer.program[line][command].data == "")
                        comment = true;
                }
                if (x > width)
                    width = x;
            }
            set_size_request((width + 1) * cell_width,
                (buffer.program.size + (basic_mode ? 0 : 2)) * cell_height);
            return true;
        }

        public int draw_icon (Cairo.Context cr, int x, int y, Command c) {
            // Size by the length of data
            int width = get_icon_width(c);
            // Background
            if (high_contrast && c.draw_params.bg_color != color_black)
                Gdk.cairo_set_source_rgba(cr, color_high_contrast_cell);
            else
                Gdk.cairo_set_source_rgba(cr, c.draw_params.bg_color);
            cr.rectangle(x, y, cell_width * width, cell_height);
            cr.fill();

            // Pixbuf icons
            if (c.pixbuf != null) {
                Cairo.Surface pb = Gdk.cairo_surface_create_from_pixbuf(c.pixbuf, get_scale_factor(), get_window());
                cr.set_source_surface(pb,
                    x + cell_width * width / 2 - c.pixbuf.width / get_scale_factor() / 2,
                    y + cell_height / 2 - c.pixbuf.height / get_scale_factor() / 2);
                cr.paint();
                if (!c.draw_params.data_draw)
                    return 1;
            }

            cr.move_to(x, y + 5); // Center of the icon
            Gdk.cairo_set_source_rgba(cr, c.draw_params.fg_color); // Foreground color

            // Draw emoji icon
            if (!c.name.has_suffix(".png") && !c.name.has_suffix(".svg")){
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
            return width;
        }

        Pango.Layout draw_icon_new_layout (string text, Pango.FontDescription font, int icon_width) {
            Pango.Layout layout = create_pango_layout(text);
            layout.set_font_description(font);
            layout.set_alignment(Pango.Alignment.CENTER);
            layout.set_width(cell_width * icon_width * Pango.SCALE);
            layout.set_justify(false);
            return layout;
        }

        private int get_icon_width (Command c) {
            int width;
            if (!c.draw_params.data_draw || c.id == "python" || c.id == "4_color")
                width = 1;
            else
                width = c.data.length / 7 + 1;
            return width;
        }

        // Creates a cairo surface that is intended to be set as a DnD icon
        public Cairo.ImageSurface get_dnd_surface (ArrayList<ArrayList<Command>> commands) {
            int width_scaled = cell_width * get_scale_factor();
            int height_scaled = cell_height * get_scale_factor();
            // Get max width
            int width = 0;
            for (int line = 0; line < commands.size; line++) {
                int w = 0;
                for (int command = 0; command < commands[line].size; command++) {
                    w+=get_icon_width(commands[line][command]);
                }
                if (w > width) width = w;
            }

            var surface = new Cairo.ImageSurface(Cairo.Format.RGB24,
                width_scaled * width, height_scaled * commands.size);
            surface.set_device_scale(get_scale_factor(), get_scale_factor());
            var ctx = new Cairo.Context(surface);

            for (int line = 0; line < commands.size; line++) {
                for (int command = 0; command < commands[line].size; command++) {
                    draw_icon(ctx, command * cell_width, line * cell_height, commands[line][command]);
                }
            }

            surface.set_device_offset(-width_scaled / 2 , -height_scaled / 2);
            return surface;
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
                Gdk.Point item;
                if (!get_icon_at_pointer(out item))
                    return;
                buffer.selection_start.x = item.x; buffer.selection_end.x = item.x;
                buffer.selection_start.y = item.y; buffer.selection_end.y = item.y;
            }
            // Set DnD icon
            var commands = buffer.selection_to_list();
            var surface = get_dnd_surface(commands);
            Gtk.drag_set_icon_surface(context, surface);
        }

        void on_drag_data_get(Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time_) {
            if (drag_source_clipboard) {
                selection_data.set_text(drag_source_clipboard_text, -1);
                return;
            }
            Gdk.Point item;
            if (get_icon_at_pointer(out item)) {
                int command_count;
                string data = buffer.selection_to_string(out command_count);
                selection_data.set_text(data, -1);
                if (context.get_selected_action() == Gdk.DragAction.MOVE) {
                    if (buffer.program[item.y][item.x].id == "nl" && command_count == 1) {
                        // New line
                        if(item.y + 1 < buffer.program.size) {
                            buffer.program[item.y].add_all(buffer.program[item.y + 1]);
                            buffer.program.remove_at(item.y + 1);
                            buffer.program[item.y].remove_at(item.x);
                        }
                        else if (buffer.program[item.y].size == 1) {
                            buffer.program.remove_at(item.y);
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
                    Gdk.Point item;
                    if(get_icon_at_pointer(out item)) {
                        set_drag_source_active(false);
                        buffer.selection_phase = SelectionPhase.SELECT_END;
                        buffer.selection_start.x = item.x;
                        buffer.selection_start.y = item.y;
                    }
                }
                else if (buffer.selection_phase == SelectionPhase.BLOCK_SELECTED) {
                    if (get_icon_at_pointer()) {
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
                    if (get_icon_at_pointer()) {
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
                if(get_icon_at_pointer()) {
                    start_dnd_copy = true;
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
            if (event.button == 3) {
                start_dnd_copy = false;
                bool icon_at_pointer = get_icon_at_pointer();
                bool selection = buffer.selection_phase == SelectionPhase.BLOCK_SELECTED;
                popup_menu_edit.visible = icon_at_pointer && !selection;
                popup_menu_copy.visible = icon_at_pointer && selection;
                popup_menu_cut.visible = icon_at_pointer && selection;
                popup_menu_sep.visible = icon_at_pointer;
                popup_menu_comment.visible = selection;
                popup_menu_uncomment.visible = selection;
                popup_menu_widget.popup_at_pointer(null);
            }
            return false;
        }

        [GtkCallback]
        void on_popup_menu_edit_activate(Gtk.MenuItem item) {
            icon_data_dialog();
        }

        [GtkCallback]
        void on_popup_menu_comment_activate(Gtk.MenuItem item) {
            buffer.selection_comment();
        }

        [GtkCallback]
        void on_popup_menu_uncomment_activate(Gtk.MenuItem item) {
            buffer.selection_uncomment();
        }

        [GtkCallback]
        bool on_popup_menu_copy_button_release_event(Gtk.Widget btn, Gdk.EventButton event) {
            copy(); return false;
        }

        [GtkCallback]
        bool on_popup_menu_paste_button_release_event(Gtk.Widget btn, Gdk.EventButton event) {
            paste(); return false;
        }

        [GtkCallback]
        bool on_popup_menu_cut_button_release_event(Gtk.Widget btn, Gdk.EventButton event) {
            cut(); return false;
        }

        bool on_key_press_event(Gdk.EventKey key_event) {
            var modifiers = Gtk.accelerator_get_default_mod_mask();

            if (key_event.keyval == Gdk.Key.Delete) {
                if (buffer.selection_phase == SelectionPhase.BLOCK_SELECTED) {
                    buffer.selection_delete();
                    buffer.backup_program();
                }
                else {
                    Gdk.Point item;
                    if(get_icon_at_pointer(out item)) {
                        if(buffer.program[item.y][item.x].id != "nl") {
                            buffer.program[item.y].remove_at(item.x);
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
                icon_data_dialog();
                return false;
            }
            if (key_event.keyval == Gdk.Key.c &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                copy();
            if (key_event.keyval == Gdk.Key.x &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                cut();
            if (key_event.keyval == Gdk.Key.v &&
                (key_event.state & modifiers) == Gdk.ModifierType.CONTROL_MASK)
                paste();
            return false;
        }

        public void paste() {
            var clipboard = get_clipboard(Gdk.SELECTION_CLIPBOARD);
            string data = clipboard.wait_for_text();
            paste_data(data);
        }

        public void paste_data(string data) {
            if (data == null || !data.contains(";") || data == "")
                return;
            buffer.selection_phase = SelectionPhase.NOTHING_SELECTED;
            var targets = Gtk.drag_dest_get_target_list(this);
            drag_source_clipboard = true;
            drag_source_clipboard_text = data;
            Gtk.drag_begin_with_coordinates(this, targets, Gdk.DragAction.COPY,
                Gdk.ModifierType.BUTTON1_MASK, null, -1, -1);
        }

        public void copy() {
            if (buffer.selection_phase == SelectionPhase.BLOCK_SELECTED) {
                var clipboard = get_clipboard(Gdk.SELECTION_CLIPBOARD);
                int command_count;
                clipboard.set_text(buffer.selection_to_string(out command_count), -1);
            }
        }

        public void cut() {
            if (buffer.selection_phase == SelectionPhase.BLOCK_SELECTED) {
                copy();
                buffer.selection_delete();
                buffer.backup_program();
            }
        }

        void icon_data_dialog() {
            Gdk.Point item;
            if(!get_icon_at_pointer(out item)) return;
            switch (buffer.program[item.y][item.x].id) {
            case "int":
                num_chooser_dialog_spin_button.set_value(double.parse(buffer.program[item.y][item.x].data));
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
                buffer.program[item.y][item.x] =
                    buffer.program[item.y][item.x].set_data(str, buffer.resource_dir);
                queue_draw();buffer.backup_program();
                break;
            case "str":
            case "obj":
            case "#":
            case "5_img":
                str_chooser_dialog_entry.text = buffer.program[item.y][item.x].data;
                str_chooser_dialog_entry.grab_focus();
                if(buffer.program[item.y][item.x].id != "obj") {
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
                buffer.program[item.y][item.x] =
                    buffer.program[item.y][item.x].set_data(str_chooser_dialog_entry.text, buffer.resource_dir);
                queue_draw();buffer.backup_program();
                break;
            case "tc":
                icon_data_dialog_tc(item.x, item.y);
                queue_draw();buffer.backup_program();
                break;
            case "python":
                icon_data_dialog_python(item.x, item.y);
                queue_draw();buffer.backup_program();
                break;
            case "4_color":
                icon_data_dialog_color(item.x, item.y);
                queue_draw();buffer.backup_program();
                break;
            case "4_font":
                icon_data_dialog_font(item.x, item.y);
                queue_draw();buffer.backup_program();
                break;
            case "key":
                icon_data_dialog_key(item.x, item.y);
                queue_draw();buffer.backup_program();
                break;
            }
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
            var gtk_settings = Gtk.Settings.get_default();
            if (gtk_settings.gtk_application_prefer_dark_theme)
                python_view.background_pattern = Gtk.SourceBackgroundPatternType.NONE;
            else
                python_view.background_pattern = Gtk.SourceBackgroundPatternType.GRID;
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

        public int mouse_to_program_x (int x, int y) {
            if (buffer.program.size == 0 || y >= buffer.program.size)
                return x;
            int result = 0;
            int i = 0;
            while (i < x && result < buffer.program[y].size) {
                i += get_icon_width(buffer.program[y][result]);
                if (i > x) break;
                result++;
            }
            if (result < 0) result = 0;
            return result;
        }

        bool get_icon_at_pointer(out Gdk.Point p = null) {
            p = Gdk.Point();
            int y = mouse_y / cell_height;
            if (y >= buffer.program.size)
                return false;
            int x = mouse_to_program_x(mouse_x / cell_width, y);
            if (x < buffer.program[y].size) {
                p.x = x; p.y = y;
                return true;
            }
            return false;
        }

        public void scroll_to_selection () {
            var scrollable = get_parent() as Gtk.Scrollable;
            if (scrollable == null) return;
            scrollable.get_hadjustment().set_value(buffer.selection_start.x * cell_width);
            scrollable.get_vadjustment().set_value(buffer.selection_start.y * cell_height);
        }
    }
}
