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
    [GtkTemplate (ui = "/io/gitlab/Turtlico/widgets/search-widget.ui")]
    class SearchWidget : Gtk.Box {
        [GtkChild]
        Gtk.ScrolledWindow find_entry_sw;
        [GtkChild]
        Gtk.ScrolledWindow replace_entry_sw;

        public ProgramView find_entry = new ProgramView ();
        public ProgramView replace_entry = new ProgramView ();
        private ProgramView programview;

        public SearchWidget (ProgramView programview) {
            this.programview = programview;
            find_entry_sw.add (find_entry);
            find_entry.basic_mode = true;
            //find_entry.show ();
            replace_entry_sw.add (replace_entry);
            replace_entry.basic_mode = true;
        }

        [GtkCallback]
        void on_find_next_btn_clicked () {
            find_next ();
        }

        [GtkCallback]
        void on_find_prev_btn_clicked () {
            find_prev ();
        }

        [GtkCallback]
        void on_replace_btn_clicked () {
            if (replace_entry.buffer.program.size == 0) return;
            if (programview.buffer.selection_phase != SelectionPhase.BLOCK_SELECTED)
                return;
            if (replace_entry.buffer.program.size == 0)
                return;
            programview.buffer.replace (replace_entry.buffer.program[0]);
            find_next ();
        }

        [GtkCallback]
        void on_replace_all_btn_clicked () {
            if (find_entry.buffer.program.size == 0) return;
            if (replace_entry.buffer.program.size == 0) return;
            programview.buffer.replace_all (find_entry.buffer.program[0], replace_entry.buffer.program[0]);
        }

        void find_next () {
            if (find_entry.buffer.program.size == 0) return;
            programview.buffer.search (find_entry.buffer.program[0]);
        }

        void find_prev () {
            if (find_entry.buffer.program.size == 0) return;
            programview.buffer.search (find_entry.buffer.program[0], true);
        }
    }
}
