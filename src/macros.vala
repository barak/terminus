/*
 * Copyright 2023 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Terminus
 *
 * Terminus is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License.
 *
 * Terminus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


namespace Terminus {
    class Macro : Object {
        private uint keyval;
        private Gdk.ModifierType state;
        private string command;

        public Macro(string key,
                     string command)
        {
            uint             keyval;
            Gdk.ModifierType state;

            Gtk.accelerator_parse(key, out keyval, out state);
            if ((keyval >= 'a') && (keyval <= 'z')) {
                keyval &= ~32;
            }

            this.keyval = keyval;
            this.state = state;
            this.command = command;
        }

        public string ?
        check_macro(uint             keyval,
                    Gdk.ModifierType state)
        {
            if ((this.keyval == keyval) && (this.state == state)) {
                return this.command;
            } else {
                return null;
            }
        }
    }

    public class Macros : Object {
        private Macro[] macro_list;

        public Macros()
        {
            Terminus.settings.changed.connect((key) => {
                if (key == "macros") {
                    this.update_macros();
                }
            });
            this.update_macros();
        }

        public void
        update_macros()
        {
            this.macro_list = {};
            var macros = Terminus.settings.get_value("macros");
            foreach (var entry in macros) {
                var key = entry.get_child_value(0);
                var command = entry.get_child_value(1);
                var macro = new Macro(key.get_string(), command.get_string());
                this.macro_list += macro;
            }
        }

        public string ?
        check_macro(uint             keyval,
                    Gdk.ModifierType state)
        {
            foreach (var macro in this.macro_list) {
                var command = macro.check_macro(keyval, state);
                if (command != null) {
                    return command;
                }
            }
            return null;
        }
    }
}
