/* compiler.vala
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
    protected class CompilerFunction {
        public string id;
        public string function;
        public string default_params;
    }
    protected class CompilerSimpleIcon {
        public string id;
        public string code;
    }
    protected class CompilerModule {
        public string id;
        public string code;
        public string[] deps;
    }

    public class Compiler {
        protected Gee.ArrayList<CompilerFunction> functions = new Gee.ArrayList<CompilerFunction> ();
        protected Gee.ArrayList<CompilerSimpleIcon> simple_icons = new Gee.ArrayList<CompilerSimpleIcon> ();
        protected Gee.ArrayList<CompilerSimpleIcon> keywords = new Gee.ArrayList<CompilerSimpleIcon> ();
        protected Gee.ArrayList<CompilerSimpleIcon> keywords_with_args = new Gee.ArrayList<CompilerSimpleIcon> ();
        protected HashTable<string, CompilerModule> modules =
            new HashTable<string, CompilerModule> (str_hash, str_equal);

        Gee.ArrayList<string> output;
        Gee.LinkedList<string> modules_to_load;
        string[] enabled_plugins;
        int out_line;
        uint param_level = 0;
        uint keyword_level = 0; // Detects whether compiler is reading a condition (if, for, while)

        public Compiler (string[] enabled_plugins) {
            this.enabled_plugins = enabled_plugins;
            var parsers = Command.create_parsers (enabled_plugins);
            foreach (var parser in parsers) {
                // Get the root node:
                Json.Node node = parser.get_root ();
                // For all commands in all categories
                var categories = node.get_object ().get_array_member ("categories");
                categories.foreach_element ((array, index_, category_node)=>{
                    var commands = category_node.get_object ().get_array_member ("commands");
                    commands.foreach_element ((array, index_, command_node)=>{
                        // Parse one command
                        Json.Object command = command_node.get_object ();
                        if (command.get_int_member ("type") == 0 || command.get_int_member ("type") == 5) {
                            CompilerFunction f = new CompilerFunction ();
                            f.id = command.get_string_member ("id");
                            f.function = command.get_string_member ("func");
                            f.default_params = command.get_string_member ("params");
                            functions.add (f);
                        }
                        else if (command.get_int_member ("type") == 4) {
                            simple_icons.add (create_simple_icon (command));
                        }
                        else if (command.get_int_member ("type") == 3) {
                            keywords.add (create_simple_icon (command));
                        }
                        else if (command.get_int_member ("type") == 6) {
                            keywords_with_args.add (create_simple_icon (command));
                        }
                        //debug(command.get_string_member("id"));
                    });
                });
                var modules = node.get_object ().get_array_member ("modules");
                modules.foreach_element ((array, index_, module_node) => {
                    var module = module_node.get_object ();
                    CompilerModule f = new CompilerModule ();
                    f.id = module.get_string_member ("id");
                    f.code = module.get_string_member ("code");
                    Gee.ArrayList<string> deps = new Gee.ArrayList<string> ();
                    if (module.has_member ("deps")) {
                        var dependencies = module.get_array_member ("deps");
                        dependencies.foreach_element ((array, dep_index, dep_node) => {
                            deps.add (dep_node.get_string ());
                        });
                    }
                    f.deps = deps.to_array ();
                    this.modules.set (f.id, f);
                });
            }
        }

        private CompilerSimpleIcon create_simple_icon (Json.Object command) {
            CompilerSimpleIcon f = new CompilerSimpleIcon ();
            f.id = command.get_string_member ("id");
            f.code = command.get_string_member ("c");
            return f;
        }

        public int out_line_to_src_line (
            Gee.ArrayList<Gee.ArrayList<Command>> program, int i) {

            string[] src = compile (program).split ("\n");
            if (i < src.length) {
                while (i > 0 && !src[i].has_prefix ("# Line: "))
                    i--;
                return int.parse (src[i].replace ("# Line: ", ""));
            }
            return -1;
        }

        public string compile (Gee.ArrayList<Gee.ArrayList<Command>> program, bool write_line_hints = true ) {
            output = new Gee.ArrayList<string> ();
            output.add ("""#!/usr/bin/python3
from turtle import *
from tempfile import NamedTemporaryFile
from PIL import Image
import math, random, os, time, sys
from datetime import datetime
color('black');speed(1);title('Turtle');colormode(255);shape('turtle');listen()
last_scene = None
os.chdir(os.path.dirname(os.path.abspath(__file__)))
# Generated code
""");
            modules_to_load = new Gee.LinkedList<string> ();
            // Plugins
            foreach (string plugin in enabled_plugins) {
                string init_module_name = null;
                if (plugin.has_prefix ("r:"))
                    init_module_name = Path.get_basename (plugin.replace ("r:", ""));
                else
                    init_module_name = Path.get_basename (Path.get_dirname (plugin));
                if (modules.contains (init_module_name))
                    modules_to_load.add (init_module_name);
            }

            var global_variables = new Gee.LinkedList<string> (); // Variables that are available in every method

            for (int y = 0; y < program.size; y++) {
                string indentation = "";
                bool increase_indent = true;
                param_level = 0;
                keyword_level = 0;
                if (write_line_hints) {
                    output.add ("# Line: " + y.to_string ());
                    output.add ("");
                }
                Command line_start_command = null;

                for (int x = 0; x < program[y].size; x++) {
                    out_line = output.size - 1;
                    // Comments
                    if (program[y][x].id == "#" && program[y][x].data == "") {
                        break;
                    }

                    // First command after indentation
                    if (program[y][x].id != "tab" && line_start_command == null) {
                        line_start_command = program[y][x];
                    }
                    // Indentation
                    if (program[y][x].id == "tab" && increase_indent) {
                        indentation = indentation + "\t"; continue;
                    }
                    else {
                        increase_indent = false;
                    }

                    // Functions
                    bool con = false;
                    foreach (var f in functions) {
                        if (program[y][x].id == f.id) {
                            parse_function (f, program, ref x, ref y, indentation);
                            con = true;
                            break;
                        }
                    }
                    if (con) continue;
                    // Gets wheter program can check next icon
                    bool check_next_icon = x + 1 < program[y].size;
                    // Cycles
                    if (program[y][x].id == "1_rep") {
                        keyword_level++;
                        if (check_next_icon && program[y][x + 1].id == ":") {
                            output.add (indentation + "while True"); continue;
                        }
                        output.add (indentation + "for iter_" +
                                   y.to_string () + "_" + x.to_string ()
                                   + " in range");
                        if (check_next_icon && (program[y][x + 1].id == "int" || program[y][x + 1].id == "obj")) {
                            // Inserts number at line added above
                            output[out_line + 1] = output[out_line + 1] +
                                                   "(" + program[y][x + 1].data + ")";
                            x++; // Skip the int icon
                        }
                        continue;
                    }
                    // Functions
                    if (program[y][x].id == "3_def") {
                        keyword_level++;
                        if (line_start_command.id != "3_def") {
                            output.add ("%sraise SyntaxError('%s')".printf (
                                indentation, _("Functions must start on a separate line!")));
                        }
                        if (x + 2 < program[y].size && program[y][x + 1].id == "obj" && program[y][x + 2].id == ":") {
                            output.add (indentation + "def " + program[y][x + 1].data + "()");
                            x++; // Skip the int icon
                        }
                        else
                            output.add (indentation + "def ");
                        continue;
                    }
                    // Data types
                    if (program[y][x].id == "int") {
                        output[out_line] = output[out_line] + program[y][x].data;
                        continue;
                    }
                    if (program[y][x].id == "str" || program[y][x].id == "key") {
                        output[out_line] = output[out_line] + "'" + program[y][x].data.replace ("'", """\'""") + "'";
                        continue;
                    }
                    // Objects (variables, user defined functions etc.)
                    if (program[y][x].id == "obj") {
                        if (get_no_indent (program, x, y) || (x > 0 && program[y][x - 1].id == "3_def")) {
                            output[out_line] = output[out_line] + program[y][x].data;
                        }
                        else if (check_next_icon &&
                        (program[y][x + 1].id[0] == '2' || program[y][x + 1].id[0] == '(')) {
                            output.add (indentation + program[y][x].data);
                        }
                        else {
                            output[out_line] = output[out_line] + program[y][x].data;
                        }
                        // Add parameters if detects value icon after object (string, int, ...)
                        // or if the object is used as a function
                        bool skip_next_command;
                        bool wrote_default;
                        string args = parse_short_args ("", "", "", program, x, y, "",
                            out skip_next_command, out wrote_default);
                        if (!wrote_default) {
                            output[output.size - 1] = output[output.size - 1] + args;
                            if (skip_next_command) x++;
                        }
                        continue;
                    }
                    // Type conversion
                    if (program[y][x].id == "tc") {
                        if (check_next_icon && program[y][x + 1].id == "obj") {
                            output[out_line] = output[out_line] +
                                               "(" + program[y][x].data +
                                               ")(" + program[y][x + 1].data + ")";
                            x++;
                        }
                        else if (check_next_icon && program[y][x + 1].id == "(") {
                            output[out_line] = output[out_line] + "(" + program[y][x].data + ")";
                        }
                        continue;
                    }
                    // Direct Python code
                    if (program[y][x].id == "python") {
                        foreach (string line in program[y][x].data.split ("\n")) {
                            output.add (indentation + line);
                        }
                        continue;
                    }

                    if (program[y][x].id == "(" || program[y][x].id == "[") {param_level++;}
                    if (program[y][x].id == ")" || program[y][x].id == "]") {param_level--;}
                    // Simple icons
                    foreach (var f in simple_icons) {
                        if (program[y][x].id == f.id) {
                            output[out_line] = output[out_line] + f.code;
                            break;
                        }
                    }
                    if (program[y][x].id == ":") {
                        // Support for one line conditions etc.
                        // The rest of the line after ":" is processed as a part of the command block
                        indentation = indentation + "\t";
                        if (param_level == 0 && keyword_level > 0) keyword_level--;
                        if (param_level != 0)
                            continue;
                        output.add (indentation);
                        out_line++;
                        // Add global variable markers on start of functions
                        if (line_start_command.id == "3_def") {
                            foreach (var v in global_variables) {
                                output[out_line] = output[out_line] + @"global $v;";
                            }
                        }
                    }

                    if (program[y][x].id == "4_color") {
                        if (param_level == 0)
                            output.add (indentation + "color" + program[y][x].data.substring (3)); // Change turtle color
                        else if (program[y][x].data == "")
                            output[out_line] = output[out_line] + "color";
                        else {
                            output[out_line] =
                                output[out_line] + program[y][x].data.substring (3); // Remove 'rgb'
                        }
                        continue;
                    }
                    if (program[y][x].id == "4_font") {
                        var font = program[y][x].data.split (";");
                        if (font.length >= 4) {
                            string family = font[0];
                            string size = font[1];
                            string fonttype = font[2];
                            string weight = font[3];
                            output[out_line] = output[out_line] + @" = ('$family', $size, '$fonttype', '$weight')";
                        }
                    }

                    // Keywords
                    foreach (var f in keywords) {
                        if (program[y][x].id == f.id) {
                            output.add (indentation + f.code + " ");
                            break;
                        }
                    }
                    foreach (var f in keywords_with_args) {
                        if (program[y][x].id == f.id) {
                            output.add (indentation + f.code + " ");
                            keyword_level++;
                            break;
                        }
                    }
                    if (program[y][x].id == "3_global" && check_next_icon && program[y][x + 1].id == "obj") {
                        if (indentation == "") {
                            global_variables.add (program[y][x + 1].data);
                        }
                        int x2 = x + 2;
                        if (x2 < program[y].size && program[y][x2].id == "2_assign") {
                            // Shorter global variable declarations glob var = [something]
                            output.add (
                                indentation + "global %1$s; %1$s".printf (program[y][x + 1].data));
                            x++; // Skip object
                        } else {
                            output.add (indentation + "global ");
                        }
                    }
                }
            }

            // Load modules
            // Resolve dependencies
            foreach (var module in modules_to_load.to_array ()) {
                if (modules.contains (module))
                    module_add_deps (modules[module], modules_to_load);
                else
                    warning (@"Module '$module' was not found in the module list!");
            }
            foreach (var module in modules_to_load) {
                if (modules.contains (module))
                    output.insert (1, modules[module].code);
            }

            output.add ("done()");
            string ret = string.joinv ("\n", output.to_array ());
            debug (_("Generated code:\n") + ret);
            return ret;
        }

        private void module_add_deps (CompilerModule module, Gee.LinkedList<string> modules_to_load) {
            foreach (string dep in module.deps) {
                if (!modules_to_load.contains (dep)) {
                    if (modules.contains (dep)) {
                        modules_to_load.add (dep);
                        module_add_deps (modules[dep], modules_to_load);
                    } else {
                        warning (@"Dependency '$dep' of module $(module.id) was not found in the module list!");
                    }
                }
            }
        }

        protected void parse_function (CompilerFunction f,
                                      Gee.ArrayList<Gee.ArrayList<Command>> program,
                                      ref int x, ref int y, string indentation) {
            if (f.function.has_prefix ("tcf_")) {
                // Add module to list of modules to load
                if (modules_to_load.index_of (f.function) < 0) {
                    modules_to_load.add (f.function);
                }
            }
            bool skip_next_command;
            // Use function's return value (do not put it on a new line)
            bool no_indent = get_no_indent (program, x, y);
            string parsed = parse_short_args (f.id, f.function, f.default_params, program,
                x, y, no_indent ? "" : indentation, out skip_next_command);
            if (no_indent) {
                output[out_line] = output[out_line] + parsed;
            }
            else output.add (parsed);
            if (skip_next_command) x++;
        }

        // Returns whether command at x,y in program should not be on its own line.
        bool get_no_indent (Gee.ArrayList<Gee.ArrayList<Command>> program, int x, int y) {
            return keyword_level > 0 || param_level > 0 || (x > 0 && program[y][x - 1].id[0] == '2');
        }

        string parse_short_args (string id, string function, string default_params,
                                Gee.ArrayList<Gee.ArrayList<Command>> program,
                                int x, int y, string indentation,
                                out bool skip_next_command, out bool wrote_default = null) {
            // Can check next icon
            bool check_next_icon = x + 1 < program[y].size;

            skip_next_command = false;
            wrote_default = false;

            string parsed = "";
            if (id == "5_img" && program[y][x].data != "") {
                parsed = indentation + function + "('" + program[y][x].data.replace ("'", """\'""") + "')";
            }
            else if (check_next_icon && program[y][x + 1].id == "(") {
                parsed = indentation + function;
            }
            else if (check_next_icon && (program[y][x + 1].id == "int" || program[y][x + 1].id == "obj")) {
                parsed = indentation + function + "(" + program[y][x + 1].data + ")";
                skip_next_command = true;
            }
            else if (check_next_icon && program[y][x + 1].id == "str") {
                parsed = indentation + function + "('" + program[y][x + 1].data.replace ("'", """\'""") + "')";
                skip_next_command = true;
            }
            else if (check_next_icon && program[y][x + 1].id[0] == '4') {
                if (program[y][x + 1].id == "4_color" && program[y][x + 1].data != "") {
                    parsed = indentation + function + "(" + program[y][x + 1].data.substring (3) + ")";
                }
                else {
                    try {
                        var si = find_simple_icon (program[y][x + 1].id);
                        parsed = indentation + function + "(" + si.code + ")";
                    }
                    catch (FileError e) {}
                }
                skip_next_command = true;
            }
            else {
                parsed = indentation + function + "(" + default_params + ")";
                wrote_default = true;
            }
            return parsed;
        }

        CompilerSimpleIcon find_simple_icon (string id) throws FileError {
            foreach (var i in simple_icons) {
                if (i.id == id)
                    return i;
            }
            throw new FileError.FAILED ("Command not found");
        }
    }
}
