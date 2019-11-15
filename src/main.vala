/* main.vala
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

extern const string LOCALE_DIR;

int main (string[] args) {
	Intl.setlocale (LocaleCategory.ALL, "");
	Intl.bind_textdomain_codeset ("turtlico", "UTF-8");

	Gtk.Sourceinit();

	string cd = GLib.Environment.get_current_dir();
	string prefix = GLib.Path.get_dirname(cd);
	string localedir = GLib.Path.build_path("/", prefix, "share", "locale");
	if (GLib.FileUtils.test(localedir, GLib.FileTest.IS_DIR))
	    Intl.bindtextdomain("turtlico", localedir);
	else
	    Intl.bindtextdomain("turtlico", LOCALE_DIR);
    Intl.textdomain ("turtlico");

#if WINDOWS
	Environment.set_variable("GTK_CSD", "0", true);
#endif
	
	var app = new Gtk.Application ("tk.turtlico.Turtlico", ApplicationFlags.HANDLES_OPEN | ApplicationFlags.HANDLES_COMMAND_LINE);
	app.add_main_option("compile", 'c', 0, OptionArg.STRING, _("Writes compiled program to FILE"), "");
	app.activate.connect (() => {
		var win = app.active_window;
		if (win == null) {
			win = new Turtlico.Window (app);
		}

		// TODO: Do this better
		win.present_with_time (Gdk.CURRENT_TIME - 1);
	});
	app.command_line.connect((cmdline)=>{
	    app.activate();
	    var win = (Turtlico.Window)app.active_window;
	    foreach (string arg in cmdline.get_arguments()) {
	        var f = cmdline.create_file_for_arg(arg);
	        if (f.get_basename().has_suffix(".tcp") && f.query_exists()) {
	            win.open_file(f);
	        }
	    }
	    var opts = cmdline.get_options_dict();
	    if (opts.contains("compile")) {
	        try {
	            var path = opts.lookup_value("compile", GLib.VariantType.STRING);
	            var file = cmdline.create_file_for_arg(path.get_string());
	            var iostream = file.create_readwrite(FileCreateFlags.NONE);
	            var dos = new DataOutputStream(iostream.output_stream);
                dos.put_string(win.compiler.compile(win.programview.buffer.program));
                iostream.close();
                win.destroy();
            }
            catch (Error e) {
                print(_("Cannot save the output file: %s\n").printf(e.message));
            }
	    }
		return 0;
	});

	return app.run (args);
}
