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
    public class Debugger : Object {
        Settings settings = new Settings ("io.gitlab.Turtlico");

        public bool debug_running { get; set; }
        Cancellable debug_cancellable = new Cancellable ();

        public signal void on_error (string title, string message);

        // Launcher that catches errors from the user-written program
        // and translates error line numbers
        private static string python_launcher = """
def get_source_line (line, lines):
    for i in range(line - 1, -1, -1):
        if i >= len(lines):
            continue
        if lines[i].startswith('# Line: '):
            return (int(lines[i][8:]) + 1)
    return -1
try:
    exec(open('%1s').read(), {'__file__':'%1s'})
except SyntaxError as e:
    import sys
    lines = open('%1s').readlines()
    print('%2s'.format('Syntax error', get_source_line(e.lineno, lines)), file=sys.stderr)
except Exception as e:
    import sys, traceback
    lines = open('%1s').readlines()
    exception_type, exception_object, exception_traceback = sys.exc_info()
    trace = traceback.extract_tb(exception_traceback)
    i = len(trace) - 1
    line_number = -1
    while i >= 0 and line_number == -1:
        line_number = get_source_line(trace[i][1], lines)
        i-=1
    message = str(e).strip()
    if message != '':
        print('%2s'.format(e, line_number), file=sys.stderr)""";

        public void stop () {
            debug_cancellable.cancel ();
        }

        public void start (Compiler compiler, ProgramBuffer buffer, File? output_file) {
            if (debug_running) {
                return;
            }
            debug_cancellable.reset ();
            debug_running = true;
            try {
                string output = compiler.compile (
                    buffer.program,
                    settings.get_boolean ("debug-data"));
                string path;
                if (output_file != null && !output_file.get_path ().has_prefix ("/run/user"))
                    path = output_file.get_path () + ".py";
                else
                    path = Path.build_filename (Environment.get_user_cache_dir (), "turtlico_output.py");
                write_to_file (path, output.data);
                // RUN
                new GLib.Thread<int> (null, () => {
                    string _stderr = "";
                    int status = 0;
                    Subprocess subprocess = null;
                    DataInputStream dise = null;
                    try {
                        var argv = new Gee.LinkedList<string> ();
#if WINDOWS
                            string pythonw = Environment.find_program_in_path ("python3w.exe");
                            argv.add (pythonw);
#else
                            GLib.Process.spawn_command_line_sync ("chmod +x '" + path + "'");
                            argv.add ("python3");
#endif
                        string err_template = _("{}\\nError occured on line {}.");
                        // The string is probably too large for printf because it causes Turtlico to crash
                        // string python_launcher = python_launcher.printf (path, err_template);
                        string python_launcher = python_launcher.replace ("%1s", path.replace ("\\", "/")).replace ("%2s", err_template);

                        if (buffer.run_in_console) {
                            argv.add_all_array ({"-m", "idlelib", "-t", "Turtlico"});
                            string exit_string = _("Press enter to close the window");
                            python_launcher += """
print('----------------------'); input('%1s')
import os, signal; os.kill(os.getppid(), signal.SIGTERM)""".printf (exit_string);
                        }
                        argv.add ("-c");
                        argv.add (python_launcher);

                        bool use_launcher = true;
#if WINDOWS
                        if (!Win32.check_windows_version (10, 0, 0, Win32.OSType.ANY)) {
                            use_launcher = false; // spawnv causes SEGFAULT on Windows 8 and older
                        }
#endif
                        if (use_launcher) {
                            var launcher = new SubprocessLauncher (
                                SubprocessFlags.STDERR_PIPE | SubprocessFlags.STDOUT_PIPE);
                            launcher.setenv ("G_MESSAGES_DEBUG", "", true);
                            launcher.setenv ("PYTHONUNBUFFERED", "x", true);
                            var argv_array = argv.to_array ().copy ();
                            subprocess = launcher.spawnv (argv_array);
                        }
                        else {
                            // Windows 8 and older
                            subprocess = new Subprocess (
                                SubprocessFlags.STDERR_PIPE | SubprocessFlags.STDOUT_PIPE, "python3w", path);
                        }
                        subprocess.wait (debug_cancellable);

                        string read = "";
                        dise = new DataInputStream (subprocess.get_stderr_pipe ());
                        while (read != null) {
                            try {
                                read = dise.read_line ();
                                _stderr += read;
                                _stderr += "\n";
                            } catch (Error e) {
                                read = null;
                            }
                        }

                        status = subprocess.get_status ();
                    }
                    catch (IOError e) {
                        // This is called when debug_cancellable is canceled (if the program is stopped by user)
                        if (subprocess != null) {
                            subprocess.force_exit ();
                            try { subprocess.wait (); } catch {}
                        }
                    }
                    catch (Error e) {
                        string error_msg = e.message;
                        Idle.add (() => {
                            on_error (error_msg, "");
                            return false;
                        });
                    }
                    try { if (dise != null) dise.close (); } catch {}; dise = null;

                    debug (_("stderr of child process:\n") + _stderr);
                    Idle.add (() => {
                        debug_running = false;
                        // Show error dialog
                        if (_stderr != null) {
                            string error = _stderr.dup ().strip ();
                            if (error != "") {
                                if (error.contains ("turtle.Terminator") ||
                                    error.contains ("_tkinter.TclError: invalid command name") ||
                                    error.has_prefix ("invalid command name")
                                ) {
                                    return false;
                                }

                                on_error (_("Program crashed"),
                                    error);
                            }
                        }
                        return false;
                    });
                    return 0;
                });

            }
            catch (Error e) {
                on_error (e.message, "");
            }
        }

        private void write_to_file (string path, uint8[] data) throws Error {
            // Save generated program
            var file = File.new_for_path (path);
            if (file.query_exists ()) {file.delete ();}
            var dos = new DataOutputStream (file.create (FileCreateFlags.NONE));
            long written = 0;
            while (written < data.length) {
                // sum of the bytes of 'data' that already have been written to the stream
                written += dos.write (data[written:data.length]);
            }
        }
    }
}
