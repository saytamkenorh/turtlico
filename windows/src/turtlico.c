/**
 * Copyright (C) 2021 saytamkenorh
 * 
 * This file is part of turtlico.
 * 
 * turtlico is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * turtlico is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with turtlico.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <glib.h>

int main (int argc, char *argv[]) {
	char* spawn_argv[argc+2];
	spawn_argv[argc+1] = NULL;

	for (int i = 1; i < argc; i++) {
		spawn_argv[i + 1] = argv[i];
	}
	char* bindir = g_path_get_dirname(argv[0]);	

	// Python interpreter
	spawn_argv[0] = g_build_filename(bindir, "pythonw.exe", NULL);
	// Turtlico Python binary
	spawn_argv[1] = g_build_filename(bindir, "turtlico", NULL);

	gint return_code;
	GError *error = NULL;	

	gboolean ok = g_spawn_sync(NULL, spawn_argv, NULL, G_SPAWN_DEFAULT, NULL, NULL, NULL, NULL, &return_code, &error);
	if (!ok) {
		if (error != NULL) {
			g_critical(error->message);
			g_critical("Turtlico launch failed!");
		} else {
			g_critical("Cannot launch Turtlico due to an unknown failure!");
		}
		return 1;
	}
	return return_code;
}
