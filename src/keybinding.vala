/*
 * Copyright 2022 (C) Raster Software Vigo (Sergio Costas)
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
    class KeyBinding : Object {
        public string name;
        public string description;
        private uint keyval;
        private Gdk.ModifierType state;

        public KeyBinding(string name,
                          string description)
        {
            this.name = name;
            this.description = description;
            Terminus.keybind_settings.changed.connect(this.settings_changed);
            this.settings_changed(name);
        }

        public void
        settings_changed(string name)
        {
            uint             keyval;
            Gdk.ModifierType state;

            if (name != this.name) {
                return;
            }

            Gtk.accelerator_parse(Terminus.keybind_settings.get_string(this.name), out keyval, out state);
            if ((keyval >= 'a') && (keyval <= 'z')) {
                keyval &= ~32;
            }
            this.keyval = keyval;
            this.state = state;
        }

        public bool
        check_key(uint             keyval,
                  Gdk.ModifierType state)
        {
            if ((this.keyval == keyval) && (this.state == state)) {
                return true;
            }
            return false;
        }
    }

    class KeyBindings : Object {
        public KeyBinding[] key_binding_list;

        public KeyBindings()
        {
            this.key_binding_list = {};
            this.add_keybinding(_("New window"), "new-window");
            this.add_keybinding(_("New tab"), "new-tab");
            this.add_keybinding(_("Next tab"), "next-tab");
            this.add_keybinding(_("Previous tab"), "previous-tab");
            this.add_keybinding(_("Show guake terminal"), "guake-mode");
            this.add_keybinding(_("Copy text into the clipboard"), "copy");
            this.add_keybinding(_("Paste text from the clipboard"), "paste");
            this.add_keybinding(_("Move focus to the terminal on the left"), "terminal-left");
            this.add_keybinding(_("Move focus to the terminal on the right"), "terminal-right");
            this.add_keybinding(_("Move focus to the terminal above"), "terminal-up");
            this.add_keybinding(_("Move focus to the terminal below"), "terminal-down");
            this.add_keybinding(_("Make font bigger"), "font-size-big");
            this.add_keybinding(_("Make font smaller"), "font-size-small");
            this.add_keybinding(_("Reset font size"), "font-size-normal");
            this.add_keybinding(_("Show menu"), "show-menu");
            this.add_keybinding(_("Split horizontally"), "split-horizontally");
            this.add_keybinding(_("Split vertically"), "split-vertically");
            this.add_keybinding(_("Close the active tile"), "close-tile");
            this.add_keybinding(_("Close the active tab"), "close-tab");
            this.add_keybinding(_("Select all"), "select-all");
            this.add_keybinding(_("Search"), "search");
        }

        private void
        add_keybinding(string description,
                       string name)
        {
            this.key_binding_list += new KeyBinding(name, description);
        }

        public string ?
        find_key(uint             keyval,
                 Gdk.ModifierType state)
        {
            // SHIFT, CTRL, LEFT ALT, ALT+GR
            state &= Gdk.ModifierType.SHIFT_MASK |
                     Gdk.ModifierType.CONTROL_MASK |
                     Gdk.ModifierType.SUPER_MASK |
                     Gdk.ModifierType.META_MASK |
                     Gdk.ModifierType.HYPER_MASK |
                     Gdk.ModifierType.ALT_MASK;

            if ((keyval <= 'z') && (keyval >= 'a')) {
                // to avoid problems with upper and lower case
                keyval &= ~32;
            }
            foreach (var key in this.key_binding_list) {
                if (key.check_key(keyval, state)) {
                    return key.name;
                }
            }
            return null;
        }
    }
}
