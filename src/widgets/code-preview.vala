/* code-preview.vala
 *
 * Copyright 2020 saytamkenorh
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
    public class CodePreview : Gtk.SourceView {
        public Compiler? compiler {get; set;}
        ProgramView programview;

        public CodePreview (ProgramView programview, Compiler? compiler) {
            var language_manager = new Gtk.SourceLanguageManager ();
            Gtk.SourceLanguage python_language = language_manager.get_language ("python3");
            Gtk.SourceBuffer python_buffer = new Gtk.SourceBuffer.with_language (python_language);
            buffer = python_buffer;
            editable = false;
            this.programview = programview;

            update_buffer ();
            programview.notify["buffer"].connect (update_buffer);

            notify["compiler"].connect (update_code);
            this.compiler = compiler;
        }

        private void update_buffer () {
            programview.buffer.redraw_required.connect (update_code);
        }

        private void update_code () {
            if (compiler == null)
                return;
            var ha = hadjustment.get_value();
            var va = vadjustment.get_value();
            buffer.set_text (compiler.compile (programview.buffer.program, false));
            hadjustment.set_value(ha);
            vadjustment.set_value(va);
        }
    }
}
