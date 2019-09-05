/* linux-setup.vala
 *
 * Copyright 2019 matyas5 <hronekmatyas@gmail.com>
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
    private const string[] linux_deps_tools = {"apt", "pacman", "dnf"};

    public void linux_check_deps(Gtk.Window win) {
        new GLib.Thread<int>(null, ()=>{
            try {
                string args = "python3 -c 'import turtle; from gi.repository import Gst;'";
#if TURTLICO_FLATPAK
                args = "flatpak-spawn --host " + args;
#endif
                string _stdout;
                string _stderr;
                int python_exit_status;
                Process.spawn_command_line_sync(args, out _stdout, out _stderr, out python_exit_status);
                debug(python_exit_status.to_string());
                if (python_exit_status != 0) {
                    string tool = "";
                    int exit_status;
                    foreach (var c in linux_deps_tools) {
                        try {
                            exit_status = -1;
#if TURTLICO_FLATPAK
                            Process.spawn_command_line_sync("flatpak-spawn --host which " + c, out _stdout, out _stderr, out exit_status);
#else
                            Process.spawn_command_line_sync("which " + c, out _stdout, out _stderr, out exit_status);
#endif
                            if (exit_status == 0) {
                                tool = c;
                                break;
                            }
                        }
                        catch {}
                    }
                    if (tool != "") {
                        Idle.add(()=>{
                            var dialog = new Gtk.MessageDialog(win,
                                Gtk.DialogFlags.MODAL,
                                Gtk.MessageType.QUESTION,
                                Gtk.ButtonsType.YES_NO,
                                _("Turtlico detected missing dependencies that are required to run Turtlico programs"));
                            dialog.secondary_text = _("Would you like to install them now?");
                            var answer = dialog.run();
                            dialog.destroy();
                            if (answer == Gtk.ResponseType.YES) {
                                try {
                                    string command = "";
#if TURTLICO_FLATPAK
                                    command = "flatpak-spawn --host ";
#endif
                                    command += "gnome-terminal -e 'sudo ";
                                    switch(tool) {
                                        case "apt":
                                            command += "apt install python3-tk gir1.2-gstreamer-1.0";
                                            break;
                                        case "pacman":
                                            command += "pacman --noconfirm -S python tk gst-python";
                                            break;
                                        case "dnf":
                                            command += "dnf install python3-tk gstreamer-python";
                                            break;
                                    }
                                    command += "'";
                                    Process.spawn_command_line_async(command);
                                }
                                catch {}
                            }
                            return false;
                        });
                    }
                }
            }
            catch (Error e) {
            }
            return 0;
        });
    }
}
