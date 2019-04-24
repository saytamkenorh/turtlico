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

    public class Compiler {
        protected Gee.ArrayList<CompilerFunction> functions = new Gee.ArrayList<CompilerFunction>();
        protected Gee.ArrayList<CompilerSimpleIcon> simple_icons = new Gee.ArrayList<CompilerSimpleIcon>();
        protected Gee.ArrayList<CompilerSimpleIcon> keywords = new Gee.ArrayList<CompilerSimpleIcon>();
        protected Gee.ArrayList<CompilerSimpleIcon> modules = new Gee.ArrayList<CompilerSimpleIcon>();

        Gee.ArrayList<string> output;
        Gee.LinkedList<string> modules_to_load;
        int out_line;

        public Compiler () {
            var parser = Command.create_parsers()[0];
            // Get the root node:
		    Json.Node node = parser.get_root ();
		    // For all commands in all categories
            var categories = node.get_object().get_array_member("categories");
            categories.foreach_element((array, index_, category_node)=>{
                var commands = category_node.get_object().get_array_member("commands");
                commands.foreach_element((array, index_, command_node)=>{
                    // Parse one command
                    Json.Object command = command_node.get_object();
                    if (command.get_int_member("type") == 0 || command.get_int_member("type") == 5){
                        CompilerFunction f = new CompilerFunction();
                        f.id = command.get_string_member("id");
                        f.function = command.get_string_member("func");
                        f.default_params = command.get_string_member("params");
                        functions.add(f);
                    }
                    else if(command.get_int_member("type") == 4) {
                        CompilerSimpleIcon f = new CompilerSimpleIcon();
                        f.id = command.get_string_member("id");
                        f.code = command.get_string_member("c");
                        simple_icons.add(f);
                    }
                    else if(command.get_int_member("type") == 3) {
                        CompilerSimpleIcon f = new CompilerSimpleIcon();
                        f.id = command.get_string_member("id");
                        f.code = command.get_string_member("c");
                        keywords.add(f);
                    }
                    //debug(command.get_string_member("id"));
                });
            });
            var modules = node.get_object().get_array_member("modules");
            modules.foreach_element((array, index_, module_node)=>{
                var module = module_node.get_object();
                CompilerSimpleIcon f = new CompilerSimpleIcon();
                f.id = module.get_string_member("id");
                f.code = module.get_string_member("code");
                this.modules.add(f);
            });
        }

        public string compile(Gee.ArrayList<Gee.ArrayList<Command>> program) {
            output = new Gee.ArrayList<string>();
            output.add("""#!/usr/bin/python3
from turtle import *
import math, random, os
color('black');speed(1);title('Turtle');colormode(255)
os.chdir(os.path.dirname(os.path.abspath(__file__)))
# Generated code""");
            modules_to_load = new Gee.LinkedList<string>();

            for(int y = 0; y < program.size; y++) {
                string indentation = "";
                bool increase_indent = true;
                uint param_level = 0;
                for(int x = 0; x < program[y].size; x++) {
                    out_line = output.size - 1;
                    // Functions
                    bool con = false;
                    foreach(var f in functions){
                        if(program[y][x].id == f.id) {
                            parse_function(f, program, ref x,  ref y, indentation);
                            con = true;
                            break;
                        }
                    }
                    if (con) continue;
                    // Gets wheter program can check next icon
                    bool check_next_icon = x + 1 < program[y].size;

                    if (program[y][x].id == "tab" && increase_indent) {
                        indentation = indentation + "\t"; continue;
                    }
                    else {
                        increase_indent = false;
                    }
                    // Cycles
                    if (program[y][x].id == "1_rep") {
                        if (check_next_icon && program[y][x + 1].id == ":") {
                            output.add(indentation + "while True"); continue;
                        }
                        output.add(indentation + "for iter_" +
                                   y.to_string() + "_" + x.to_string()
                                   + " in range");
                        if (check_next_icon && (program[y][x+1].id == "int" || program[y][x+1].id == "obj")){
                            // Inserts number at line added above
                            output[out_line + 1] = output[out_line + 1] +
                                                   "(" + program[y][x + 1].data + ")";
                            x++; // Skip the int icon
                        }
                        continue;
                    }
                    if (program[y][x].id == "1_for") {
                        output.add(indentation + "for "); continue;
                    }
                    // Functions
                    if (program[y][x].id == "3_def") {
                        output.add(indentation + "def "); continue;
                    }
                    // Data types
                    if (program[y][x].id == "int") {
                        output[out_line] = output[out_line] + program[y][x].data;
                        continue;
                    }
                    if (program[y][x].id == "str") {
                        output[out_line] = output[out_line] + "'" + program[y][x].data + "'";
                        continue;
                    }
                    // Objects (variables, user defined functions etc.)
                    if (program[y][x].id == "obj") {
                        if (x > 0 && (program[y][x - 1].id == "3_def" ||
									       program[y][x - 1].id == "2_assign" ||
									       program[y][x - 1].id == "2_."))
						{
						    output[out_line] = output[out_line] + program[y][x].data;
						}
						else if (check_next_icon && (program[y][x + 1].id[0] == '2' ||
						                                program[y][x + 1].id[0] == '(' ||
						                                program[y][x + 1].id == "2_.")
						         && param_level == 0)
						{
                            output.add(indentation + program[y][x].data);
						}
						else {
						    output[out_line] = output[out_line] + program[y][x].data;
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

                    if (program[y][x].id == "(") {param_level++;}
			        if (program[y][x].id == ")") {param_level--;}
			        // Simple icons
                    foreach (var f in simple_icons) {
                        if(program[y][x].id == f.id) {
                            output[out_line] = output[out_line] + f.code;
                            break;
                        }
                    }
                    // Keywords
                    foreach (var f in keywords) {
                        if(program[y][x].id == f.id) {
                            output.add(indentation + f.code + " ");
                            break;
                        }
                    }
                }
            }

            // Load modules
            foreach (var module in modules) {
                if (modules_to_load.index_of(module.id) > -1) {
                    output.insert(1, module.code);
                }
            }

            output.add("listen();done()");
            string ret = string.joinv("\n", output.to_array());
            debug("\n" + ret);
            return ret;
        }

        protected void parse_function(CompilerFunction f,
                                      Gee.ArrayList<Gee.ArrayList<Command>> program,
                                      ref int x, ref int y, string indentation)
        {
            if (f.function.has_prefix("tcf_")){
                // Add module to list of modules to load
                if(modules_to_load.index_of(f.function) < 0) {
                    modules_to_load.add(f.function);
                }
            }
            bool skip_next_command = false;
            // Can check next icon
            bool check_next_icon = x + 1 < program[y].size;
            string parsed = "";
            if (check_next_icon && program[y][x + 1].id == "(") {
                parsed = indentation + f.function;
            }
            else if (check_next_icon && (program[y][x + 1].id == "int" || program[y][x+1].id == "obj")){
                parsed = indentation + f.function + "(" + program[y][x+1].data + ")";
                skip_next_command = true;
            }
            else if (check_next_icon && program[y][x + 1].id == "str"){
                parsed = indentation + f.function + "('" + program[y][x+1].data + "')";
                skip_next_command = true;
            }
            else if (check_next_icon && program[y][x + 1].id[0] == '4') {
                parsed = indentation + f.function + "(" + program[y][x+1].id.substring(2) + ")";
                skip_next_command = true;
            }
            else {
                parsed = indentation + f.function + "(" + f.default_params + ")";
            }
            // Return functions
            if(program[y][x].id[0] == '5' || (x > 0 && program[y][x - 1].id == "2_."))
                output[out_line] = output[out_line] + parsed;
            else output.add(parsed);
            if(skip_next_command) x++;
        }
    }
}
