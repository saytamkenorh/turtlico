/* debugger.vala
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

namespace Turtlico {
    public class Debugger : Object{
        Settings settings = new Settings("tk.turtlico.Turtlico");

        public bool debug_running { get; set; }
        Cancellable debug_cancellable = new Cancellable();

        public signal void on_error (string title, string message);

        public void stop() {
            debug_cancellable.cancel();
        }

        public void start(Compiler compiler, ProgramBuffer buffer, File? output_file) {
            if (debug_running) {
                return;
            }
            debug_cancellable.reset();
            debug_running = true;
            try {
                string output = compiler.compile(buffer.program,
                    settings.get_boolean("debug-data"));
                string path;
                if (output_file != null && !output_file.get_path().has_prefix("/run/user"))
                    path = output_file.get_path() + ".py";
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
                new GLib.Thread<int>(null, ()=>{
                    string _stdout = "";
                    string _stderr = "";
                    int status = 0;
                    Subprocess subprocess = null;
                    try {
                        var argv = new Gee.LinkedList<string>();
#if WINDOWS
                            argv.add("python3w");
#else
                            GLib.Process.spawn_command_line_sync("chmod +x '" + path + "'");
#if TURTLICO_FLATPAK
                            argv.add_all_array({"flatpak-spawn", "--host", "python3"});
#else
                            argv.add("python3");
#endif
#endif
                        argv.add(path);
                        bool use_launcher = true;
#if WINDOWS
                        if(!Win32.check_windows_version(10, 0, 0, Win32.OSType.ANY))
                        {
                            use_launcher = false; // spawnv causes SEGFAULT on Windows 8 and older
                        }
#endif
                        if (use_launcher) {
                            var launcher = new SubprocessLauncher(SubprocessFlags.STDERR_PIPE | SubprocessFlags.STDOUT_PIPE);
                            launcher.setenv("G_MESSAGES_DEBUG", "all", true);
                            subprocess = launcher.spawnv(argv.to_array());
                        }
                        else {
                            subprocess = new Subprocess(SubprocessFlags.STDERR_PIPE | SubprocessFlags.STDOUT_PIPE, "python3w", path);
                        }

                        subprocess.wait(debug_cancellable);
                        var dis = new DataInputStream (subprocess.get_stdout_pipe());
                        _stdout = dis.read_upto("\0", 1, null);
                        dis.close();
                        dis = new DataInputStream (subprocess.get_stderr_pipe());
                        _stderr = dis.read_upto("\0", 1, null);
                        dis.close();
                        status = subprocess.get_status();
                    }
                    catch (IOError e) {
                        if (subprocess != null) {
                            subprocess.force_exit();
#if TURTLICO_FLATPAK
                            try {
                                if (_stdout == "") {
                                    var dis = new DataInputStream (subprocess.get_stdout_pipe());
                                    _stdout = dis.read_line(); // We need just the PID
                                }
                                string pid_msg = "child_pid: ";
                                int pid_index = _stdout.index_of(pid_msg);
                                if (pid_index >= 0) {
                                    int pid_index_start = pid_index + pid_msg.length;
                                    string pid = _stdout.substring(pid_index_start);
                                    GLib.Process.spawn_command_line_async("flatpak-spawn --host kill -SIGKILL " + pid);
                                }
                            } catch {}
#endif
                        }
                    }
                    catch (Error e) {
                        string error_msg = e.message;
                        Idle.add(()=>{
                            on_error(error_msg, "");
                            return false;
                        });
                    }
                    debug(_("stdout of child process:\n") + _stdout);
                    debug(_("stderr of child process:\n") + _stderr);
                    Idle.add(()=>{
                        debug_running = false;
                        // Show error dialog
                        if (status != 0 && _stderr != "") {
                            string[] err_lines = _stderr.split("\n");
                            string error = err_lines[err_lines.length - 2];
                            if (_stderr.contains("turtle.Terminator"))
                                return false;
                            // Extracts line
                            if (settings.get_boolean("debug-data")) {
                                Gee.ArrayList<string> words = new Gee.ArrayList<string>.wrap(_stderr.split(" "));
                                int i = 0;
                                bool search_for_line = false;
                                for (int index = 0; index < words.size; index ++) {
                                    if (words[index].contains(path))
                                        search_for_line = true;
                                    if (search_for_line && words[index] == "line") {
                                        i = index;
                                        break;
                                    }
                                }
                                int code_line = int.parse(words[i + 1].replace(",", ""));
                                debug(words[i + 1]);
                                code_line--; // Python indexes lines from 1
                                int line = compiler.out_line_to_src_line(buffer.program, code_line);
                                if (line >= 0) {
                                    line++; // We show line numbers indexed from 1 to user
                                    error += "\n" + _("Error occurred at line ") + line.to_string();
                                }
                            }

                            on_error(_("Program crashed"),
                                error);
                        }
                        return false;
                    });
                    return 0;
                });

            }
            catch (Error e) {
                on_error(e.message, "");
            }
        }
    }
} 
