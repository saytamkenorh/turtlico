/* search-widget.vala
 *
 * Copyright 2020 matyas5
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
    [GtkTemplate (ui = "/tk/turtlico/Turtlico/search-widget.ui")]
    class SearchWidget : Gtk.Box {
        [GtkChild]
        Gtk.ScrolledWindow find_entry_sw;

        public ProgramView find_entry = new ProgramView();
        public ProgramView replace_entry = new ProgramView();
        private ProgramView programview;

        public SearchWidget (ProgramView programview) {
            this.programview = programview;
            find_entry_sw.add(find_entry);
            find_entry.basic_mode = true;
            find_entry.show();
        }

        [GtkCallback]
        void on_find_next_btn_clicked() {
            programview.buffer.search(find_entry.buffer.program[0]);
        }

        [GtkCallback]
        void on_find_prev_btn_clicked() {
            programview.buffer.search(find_entry.buffer.program[0], true);
        }
    }
}
