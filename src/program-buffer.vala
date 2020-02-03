/* programbuffer.vala
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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using Gee;

namespace Turtlico {
    public enum SelectionPhase {
        NOTHING_SELECTED,
        SELECT_END,
        BLOCK_SELECTED
    }

    public class ProgramBuffer : Object {
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

        public string resource_dir = "";

        // Selection
        public Gdk.Point selection_start;
        public Gdk.Point selection_end;
        public SelectionPhase selection_phase = SelectionPhase.NOTHING_SELECTED;

        public static string str_mark = ((char)31).to_string(); //Unit separator
        public static string str_mark_utf8 = "~";

        public signal void redraw_required();

        public bool save_history = true;

        public ProgramBuffer () {
        }

        public void undo () {
            if (history.size - history_index - 2 < 0)
                return;
            var h = history[history.size - history_index - 2];
            copy_list(h, ref program);
            redraw_required();
            history_index++;
            program_changed = true;
        }

        public void redo() {
            if (history_index == 0)
                return;
            history_index--;
            var h = history[history.size - history_index - 1];
            copy_list(h, ref program);
            redraw_required();
            program_changed = true;
        }

        public void backup_program () {
            if (!save_history)
                return;
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
                bool ignore = false;
                string tuple = "";
                for(int i = 0; i < line.length; i++){
                    if(line[i] == ';'){
                        if(!ignore){
                            cmds.add(tuple.replace("\\n", "\n"));
                            tuple = "";
                            continue;
                        }
                    }
                    else if(line[i] == str_mark[0]){
                        ignore = !ignore;
                    }
                    tuple = tuple + line[i].to_string();
                }
                // Parse
                program.add(new Gee.ArrayList<Turtlico.Command>());
                int y = program.size - 1;
                foreach (string cmd in cmds) {
                    // Properties (id, data)
                    Gee.LinkedList<string> props = new Gee.LinkedList<string>();
                    ignore = false;
                    string prop = "";
                    foreach (char c in cmd.to_utf8()) {
                        if (!ignore && c == ',') {
                            props.add(prop);
                            prop = "";
                            continue;
                        }
                        if (c == str_mark[0])
                            ignore = !ignore;
                        else
                            prop = prop + c.to_string();
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
                         throw new IOError.INVALID_DATA(_("Failed to open the file. Error on line: ") + y.to_string());
                    }
                    try {
                        Command c = find_command_by_id(props[0]);
                        // Set data only if necessary
                        if (props[1] != "") c = c.set_data(props[1], resource_dir);

                        program[y].add(c);
                    }
                    catch (FileError e) {
                        string message = _("The file to load contains an unkown command!\n");
                        message += _("This might be because of the file was damaged or created by a newer version of this program.\nCommand ID: ") + props[0];
                        throw new IOError.INVALID_DATA(message);
                    }
                }
                if (program[y].size == 0) {program.remove_at(y);}

            }  while (line != null);
            redraw_required();
            // History
            history.clear();
            history_index = 0;
            backup_program();
            program_changed = false;
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

        public void selection_foreach (Func<Gdk.Point?> func) {
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

        public void selection_delete () {
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
            redraw_required();
        }

        public string selection_to_string (out int command_count) {
            string data = "";
            int c = 0;
            selection_foreach((p)=>{
                data += program[p.y][p.x].id + ";" + program[p.y][p.x].data + str_mark_utf8;
                c++;
            });
            command_count = c;
            return data;
        }

        public void selection_comment() {
            Command comment;
            try {
                comment = find_command_by_id("#");
            } catch {return;}

            if (selection_end.x < program[selection_end.y].size - 1)
                insert_new_line(selection_end.x + 1, selection_end.y, true);
            if (selection_start.x > 0) {
                insert_new_line(selection_start.x, selection_start.y, true);
                selection_start.y++; selection_end.y++;
            }

            for (int line = selection_start.y; line <= selection_end.y; line++) {
                int x = 0;
                while(x < program[line].size && program[line][x].id == "tab") x++;
                if(program[line][x].id != "#")
                    program[line].insert(x, comment);
            }
            selection_phase = SelectionPhase.NOTHING_SELECTED;
            redraw_required();
            backup_program();
        }

        public void selection_uncomment() {
            for (int line = selection_start.y; line <= selection_end.y; line++) {
                int x = 0;
                while(x < program[line].size && program[line][x].id == "tab") x++;
                if(program[line][x].id == "#")
                    program[line].remove_at(x);
            }
            selection_phase = SelectionPhase.NOTHING_SELECTED;
            redraw_required();
            backup_program();
        }

        public void selection_select(int start_x, int start_y, int end_x, int end_y) {
            Gdk.Point selection_start = Gdk.Point();
            selection_start.x = start_x; selection_start.y = start_y;
            Gdk.Point selection_end = Gdk.Point();
            selection_end.x = end_x; selection_end.y = end_y;
            bool swap = false;
            if (selection_start.x > selection_end.x && selection_start.y == selection_end.y)
                swap = true;
            if (selection_start.y > selection_end.y)
                swap = true;
            if (swap) {
                var temp = selection_end;
                selection_end = selection_start;
                selection_start = temp;
            }
            this.selection_start = selection_start;
            this.selection_end = selection_end;
            this.selection_phase = SelectionPhase.BLOCK_SELECTED;
            redraw_required();
        }

        public Command find_command_by_id(string id) throws GLib.FileError {
            for (int i = 0; i < commands.size; i++) {
                if(commands[i].id == id) {
                    return commands[i];
                }
            }
            throw new GLib.FileError.FAILED("Command not found");
        }

        public void fix_blank_lines () {
            for (int line = 0; line < program.size; line++) {
                if (program[line].size == 0) {
                    program.remove_at(line);
                    line--;
                }
            }
        }

        public void insert_new_line(int x, int y, bool auto_indent) {
            var new_line = new Gee.ArrayList<Turtlico.Command>();
            new_line.add(commands[0]);
            program.insert(y + 1, new_line);
            // Get commands beyond the dropped new line
            var beyond = new Gee.ArrayList<Command>.wrap(program[y].slice(x, program[y].size - 1).to_array());
            program[y + 1].insert_all(0, beyond);
            for (int i = 0; i < program[y + 1].size - 1; i++) {
                program[y].remove_at(x);
            }
            // Auto indent
            if(auto_indent) {
                // Get number of tabs on current line
                int n = 0;
                while(n < program[y].size && program[y][n].id == "tab") {
                    new_line.insert(0, commands[1]);
                    n++;
                }
            }
        }

        // This searches for 'commands'. It selects the first occurrence after current selection.
        // If it finds an occurrence it will return true
        public bool search(Gee.ArrayList<Turtlico.Command> commands, bool backwards = false) {
            if (commands.size == 0) return false;
            if (commands.last().id == "nl") {
                commands.remove(commands.last());
            }
            int match;
            bool has_start = selection_phase == SelectionPhase.BLOCK_SELECTED;
            bool rolled = false;
            if (backwards) {
                int selection_end_x = 0;
                for (int line = (has_start ? selection_start.y : program.size - 1); line >= 0; line--) {
                    match = commands.size - 1;
                    for (int command = (has_start && line == selection_start.y ? selection_start.x - 1 : program[line].size - 1); command >= 0; command--) {
                        Command c = program[line][command];
                        if (commands[match].id == c.id && commands[match].data == c.data) {
                            if (match == commands.size - 1) selection_end_x = command;
                            match--;
                        }
                        if (match == -1) {
                            selection_select(command, line, selection_end_x, line);
                            return true;
                        }
                    }
                    if (line == 0 && !rolled) {rolled = true; line = program.size; has_start = false;}
                }
            }
            else {
                int selection_start_x = 0;
                for (int line = (has_start ? selection_end.y : 0); line < program.size; line++) {
                    match = 0;
                    for (int command = (has_start && line == selection_end.y ? selection_end.x + 1 : 0); command < program[line].size; command++) {
                        Command c = program[line][command];
                        if (commands[match].id == c.id && commands[match].data == c.data) {
                            if (match == 0) selection_start_x = command;
                            match++;
                        }
                        if (match == commands.size) {
                            selection_select(selection_start_x, line, command , line);
                            return true;
                        }
                    }
                    if (line == program.size - 1 && !rolled) {rolled = true; line = -1; has_start = false;}
                }
            }
            return false;
        }

        public void replace(Gee.ArrayList<Turtlico.Command> commands) {
            _replace(commands, true);
        }

        private void _replace(Gee.ArrayList<Turtlico.Command> commands, bool save_history) {
            if (commands.size == 0) return;
            if (commands.last().id == "nl")
                commands.remove(commands.last());
            Gdk.Point insertion_point = selection_start;
            selection_delete();
            program[insertion_point.y].insert_all(
                insertion_point.x, commands);
            redraw_required();
            if (save_history)
                backup_program();
            selection_select(selection_start.x, selection_start.y,
                selection_start.x, selection_start.y);
        }

        public void replace_all(Gee.ArrayList<Turtlico.Command> find, Gee.ArrayList<Turtlico.Command> replacewith) {
            while (search(find)) {
                _replace(replacewith, false);
            }
            backup_program();
            selection_phase = SelectionPhase.NOTHING_SELECTED;
            redraw_required();
        }
    }
}
