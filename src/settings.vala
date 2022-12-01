/*
 * Copyright 2016 (C) Raster Software Vigo (Sergio Costas)
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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using Gtk;
using Gdk;

namespace Terminus {
    class HTMLColorButton : Object {
        private Gtk.ColorButton color_button;
        private Gtk.ToggleButton ?toggle_button;
        private string property_name;
        private ulong connect_id;
        private ulong enable_id;

        public signal void
        color_set();

        public HTMLColorButton(Gtk.Builder builder,
                               string      color_button,
                               string ?    enable_button)
        {
            property_name = color_button.replace("_", "-");
            this.color_button = builder.get_object(color_button) as Gtk.ColorButton;
            if (enable_button != null) {
                this.toggle_button = builder.get_object(enable_button) as Gtk.ToggleButton;
                this.enable_id = this.toggle_button.toggled.connect(() => {
                    this.set_status();
                });
            } else {
                this.toggle_button = null;
            }
            this.connect_id = this.color_button.color_set.connect(() => {
                this.set_status();
                this.color_set();
            });
            var current_color = Gdk.RGBA();
            var parsed = current_color.parse(Terminus.settings.get_string(this.property_name));
            if (this.toggle_button != null) {
                this.toggle_button.active = parsed;
                this.color_button.sensitive = parsed;
            }
            if (parsed) {
                this.color_button.rgba = current_color;
            }
        }

        ~HTMLColorButton()
        {
            this.color_button.disconnect(this.connect_id);
            this.toggle_button.disconnect(this.enable_id);
        }

        public void
        set_status()
        {
            if (this.toggle_button != null) {
                if (!this.toggle_button.active) {
                    Terminus.settings.set_string(this.property_name, "");
                }
                this.color_button.sensitive = this.toggle_button.active;
            } else {
                var rgba = this.color_button.rgba;
                Terminus.settings.set_string(this.property_name, "#%02X%02X%02X".printf((uint) (255 * rgba.red),
                                                                                        (uint) (255 * rgba.green),
                                                                                        (uint) (255 * rgba.blue)));
            }
        }

        public void
        set_rgba(Gdk.RGBA new_color)
        {
            this.color_button.rgba = new_color;
            this.set_status();
        }
    }

    class Properties : Gtk.Window {
        private Gtk.CheckButton use_system_font;
        private Gtk.CheckButton infinite_scroll;
        private Gtk.CheckButton enable_guake_mode;
        private Gtk.CheckButton use_bold_color;
        private Gtk.CheckButton use_cursor_color;
        private Gtk.CheckButton use_highlight_color;
        private Gtk.CheckButton use_custom_shell;
        private Gtk.SpinButton scroll_value;
        private Gtk.Button custom_font;

        private HTMLColorButton fg_color;
        private HTMLColorButton bg_color;
        private HTMLColorButton bold_color;
        private HTMLColorButton cursor_color_fg;
        private HTMLColorButton cursor_color_bg;
        private HTMLColorButton highlight_color_fg;
        private HTMLColorButton highlight_color_bg;
        private HTMLColorButton focused_fg_color;
        private HTMLColorButton focused_bg_color;
        private HTMLColorButton inactive_fg_color;
        private HTMLColorButton inactive_bg_color;

        private Gtk.ColorButton[] palette_colors;

        private Gtk.ComboBox color_scheme;
        private Gtk.ListStore color_schemes;
        private Gtk.ComboBox palette_scheme;
        private Gtk.ListStore palette_schemes;
        private Gtk.ComboBox cursor_shape;
        private Gtk.ListStore keybindings;
        private Gtk.Entry custom_shell;

        private bool editing_keybind;
        private bool changing_guake;
        private string old_keybind;
        private Gtk.TreePath old_keybind_path;
        private bool disable_palette_change;

        public Properties()
        {
            this.editing_keybind = false;
            disable_palette_change = false;

            this.delete_event.connect((w) => {
                this.hide();
                return true;
            });

            var      main_window = new Gtk.Builder();
            string[] elements =
            { "properties_notebook", "color_schemes", "palette_schemes", "scroll_lines", "transparency_level",
              "cursor_liststore" };
            main_window.add_objects_from_resource("/com/rastersoft/terminus/interface/properties.ui", elements);
            this.add(main_window.get_object("properties_notebook") as Gtk.Widget);

            var label_version = main_window.get_object("label_version") as Gtk.Label;
            label_version.label = _("Version %s").printf(Constants.VERSION);

            this.use_system_font = main_window.get_object("use_system_font") as Gtk.CheckButton;
            this.use_custom_shell = main_window.get_object("use_custom_shell") as Gtk.CheckButton;
            use_custom_shell.toggled.connect(() => {
                this.custom_shell.sensitive = this.use_custom_shell.active;
            });
            this.custom_font = main_window.get_object("custom_font") as Gtk.Button;
            use_system_font.toggled.connect(() => {
                this.custom_font.sensitive = this.use_system_font.active;
            });

            this.fg_color = new HTMLColorButton(main_window, "fg_color", null);
            this.bg_color = new HTMLColorButton(main_window, "bg_color", null);
            this.bold_color = new HTMLColorButton(main_window, "bold_color", "use_bold_color");
            this.cursor_color_fg = new HTMLColorButton(main_window, "cursor_fg_color", "use_cursor_color");
            this.cursor_color_bg = new HTMLColorButton(main_window, "cursor_bg_color", "use_cursor_color");
            this.highlight_color_fg = new HTMLColorButton(main_window, "highlight_fg_color", "use_highlight_color");
            this.highlight_color_bg = new HTMLColorButton(main_window, "highlight_bg_color", "use_highlight_color");
            this.focused_fg_color = new HTMLColorButton(main_window, "focused_fg_color", null);
            this.focused_bg_color = new HTMLColorButton(main_window, "focused_bg_color", null);
            this.inactive_fg_color = new HTMLColorButton(main_window, "inactive_fg_color", null);
            this.inactive_bg_color = new HTMLColorButton(main_window, "inactive_bg_color", null);

            this.use_bold_color = main_window.get_object("use_bold_color") as Gtk.CheckButton;
            this.use_cursor_color = main_window.get_object("use_cursor_color") as Gtk.CheckButton;
            this.use_highlight_color = main_window.get_object("use_highlight_color") as Gtk.CheckButton;

            this.color_scheme = main_window.get_object("color_scheme") as Gtk.ComboBox;
            this.color_schemes = main_window.get_object("color_schemes") as Gtk.ListStore;
            this.palette_scheme = main_window.get_object("palette_scheme") as Gtk.ComboBox;
            this.palette_schemes = main_window.get_object("palette_schemes") as Gtk.ListStore;
            this.cursor_shape = main_window.get_object("cursor_shape") as Gtk.ComboBox;
            this.palette_colors = {};
            string[] palette_string = Terminus.settings.get_strv("color-palete");
            var      tmpcolor = Gdk.RGBA();
            for (int i = 0; i < 16; i++) {
                Gtk.ColorButton palette_button = main_window.get_object("palette%d".printf(i)) as Gtk.ColorButton;
                tmpcolor.parse(palette_string[i]);
                palette_button.set_rgba(tmpcolor);
                this.palette_colors += palette_button;
            }

            foreach (var button in this.palette_colors) {
                button.color_set.connect(() => {
                    this.updated_palette();
                });
            }

            this.palette_scheme.changed.connect(() => {
                var selected = this.palette_scheme.get_active();
                if (selected < 0) {
                    return;
                }
                Gtk.TreeIter iter;
                this.palette_scheme.get_active_iter(out iter);
                GLib.Value selectedCell;
                this.palette_schemes.get_value(iter, 1, out selectedCell);
                selected = selectedCell.get_int();
                var scheme = Terminus.main_root.palettes[selected];
                if (scheme.custom) {
                    return;
                }
                int i = 0;
                this.disable_palette_change = true;
                foreach (var color in scheme.get_palette()) {
                    this.palette_colors[i].set_rgba(color);
                    i++;
                }
                this.disable_palette_change = false;
                this.updated_palette();
            });

            this.color_scheme.changed.connect(() => {
                var selected = this.color_scheme.get_active();
                if (selected < 0) {
                    return;
                }
                Gtk.TreeIter iter;
                this.color_scheme.get_active_iter(out iter);
                GLib.Value selectedCell;
                this.color_schemes.get_value(iter, 1, out selectedCell);
                selected = selectedCell.get_int();
                var scheme = Terminus.main_root.palettes[selected];
                if (scheme.custom) {
                    return;
                }
                this.fg_color.set_rgba(scheme.text_fg);
                this.bg_color.set_rgba(scheme.text_bg);
            });

            this.fg_color.color_set.connect(() => {
                this.color_scheme.set_active(this.get_current_scheme());
            });
            this.bg_color.color_set.connect(() => {
                this.color_scheme.set_active(this.get_current_scheme());
            });

            var scroll_lines = main_window.get_object("scroll_lines") as Gtk.Adjustment;
            this.infinite_scroll = main_window.get_object("infinite_scroll") as Gtk.CheckButton;
            this.scroll_value = main_window.get_object("scroll_spinbutton") as Gtk.SpinButton;
            this.infinite_scroll.toggled.connect(() => {
                this.scroll_value.sensitive = !this.infinite_scroll.active;
            });

            this.enable_guake_mode = main_window.get_object("enable_guake_mode") as Gtk.CheckButton;

            this.custom_shell = main_window.get_object("command_shell") as Gtk.Entry;

            Terminus.settings.bind("cursor-shape", this.cursor_shape, "active", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("use-system-font", this.use_system_font, "active",
                                   GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.INVERT_BOOLEAN);
            Terminus.settings.bind("terminal-font", this.custom_font, "font_name", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("scroll-lines", scroll_lines, "value", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("infinite-scroll", this.infinite_scroll, "active", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("scroll-on-output", main_window.get_object(
                                       "scroll_on_output") as Gtk.CheckButton, "active",
                                   GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("scroll-on-keystroke", main_window.get_object(
                                       "scroll_on_keystroke") as Gtk.CheckButton, "active",
                                   GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("enable-guake-mode", this.enable_guake_mode, "active",
                                   GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("terminal-bell", main_window.get_object(
                                       "terminal_bell") as Gtk.CheckButton, "active", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("shell-command", this.custom_shell, "text", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("use-custom-shell", this.use_custom_shell, "active", GLib.SettingsBindFlags.DEFAULT);

            int counter = -1;
            foreach (var scheme in Terminus.main_root.palettes) {
                counter++;
                if ((!scheme.custom) && (scheme.text_fg == null)) {
                    continue;
                }
                Gtk.TreeIter iter;
                this.color_schemes.append(out iter);
                var name = GLib.Value(typeof(string));
                name.set_string(scheme.name);
                this.color_schemes.set_value(iter, 0, name);
                var id = GLib.Value(typeof(int));
                id.set_int(counter);
                this.color_schemes.set_value(iter, 1, id);
            }
            this.color_scheme.set_active(this.get_current_scheme());

            this.custom_shell.sensitive = this.use_custom_shell.active;
            this.custom_font.sensitive = this.use_system_font.active;
            this.scroll_value.sensitive = !this.infinite_scroll.active;

            counter = -1;
            foreach (var scheme in Terminus.main_root.palettes) {
                counter++;
                if ((!scheme.custom) && (scheme.get_palette().length == 0)) {
                    continue;
                }
                Gtk.TreeIter iter;
                this.palette_schemes.append(out iter);
                var name = GLib.Value(typeof(string));
                name.set_string(scheme.name);
                this.palette_schemes.set_value(iter, 0, name);
                var id = GLib.Value(typeof(int));
                id.set_int(counter);
                this.palette_schemes.set_value(iter, 1, id);
            }
            this.palette_scheme.set_active(this.get_current_palette());

            this.keybindings = new Gtk.ListStore(3, typeof(string), typeof(string), typeof(string));
            foreach (var kb in Terminus.key_bindings.key_binding_list) {
                this.add_keybinding(kb.description, kb.name);
            }

            var keybindings_view = main_window.get_object("keybindings") as Gtk.TreeView;
            keybindings_view.activate_on_single_click = true;
            keybindings_view.row_activated.connect(this.keybind_clicked_cb);
            keybindings_view.set_model(this.keybindings);
            Gtk.CellRendererText cell = new Gtk.CellRendererText();
            keybindings_view.insert_column_with_attributes(-1, _("Action"), cell, "text", 0);
            keybindings_view.insert_column_with_attributes(-1, _("Key"), cell, "text", 1);

            this.events = Gdk.EventMask.KEY_PRESS_MASK;
            this.key_press_event.connect(this.on_key_press);
        }

        private void
        updated_palette()
        {
            if (this.disable_palette_change) {
                return;
            }

            string[] old_palette = Terminus.settings.get_strv("color-palete");
            string[] new_palette = {};
            bool     changed = false;
            int      i = 0;
            foreach (var button in this.palette_colors) {
                var color = button.rgba;
                var color_str =
                    "#%02X%02X%02X".printf((int) (color.red * 255), (int) (color.green * 255),
                                           (int) (color.blue * 255));
                new_palette += color_str;
                if (old_palette[i] != color_str) {
                    changed = true;
                }
                i++;
            }
            if (changed) {
                Terminus.settings.set_strv("color-palete", new_palette);
                this.palette_scheme.set_active(this.get_current_palette());
            }
        }

        private int
        get_current_palette()
        {
            int counter = 0;
            int selected = 0;
            foreach (var scheme in Terminus.main_root.palettes) {
                if ((!scheme.custom) && (scheme.get_palette().length == 0)) {
                    continue;
                }
                if (scheme.compare_palette()) {
                    selected = counter;
                    break;
                }
                counter++;
            }
            return selected;
        }

        private int
        get_current_scheme()
        {
            int counter = 0;
            int selected = 0;
            foreach (var scheme in Terminus.main_root.palettes) {
                if ((!scheme.custom) && (scheme.text_fg == null)) {
                    continue;
                }
                if (scheme.compare_scheme()) {
                    selected = counter;
                    break;
                }
                counter++;
            }
            return selected;
        }

        private void
        add_keybinding(string name,
                       string setting)
        {
            Gtk.TreeIter iter;
            this.keybindings.append(out iter);
            this.keybindings.set(iter, 0, name, 1, Terminus.keybind_settings.get_string(setting), 2, setting);
        }

        public void
        keybind_clicked_cb(TreePath       path,
                           TreeViewColumn column)
        {
            Gtk.TreeIter iter;
            GLib.Value   val;

            if (this.editing_keybind) {
                this.editing_keybind = false;
                this.keybindings.get_iter(out iter, this.old_keybind_path);
                this.keybindings.set(iter, 1, this.old_keybind);
                if (this.changing_guake) {
                    Terminus.keybind_settings.set_string("guake-mode", old_keybind);
                }
            } else {
                this.editing_keybind = true;
                this.keybindings.get_iter(out iter, path);
                this.keybindings.get_value(iter, 1, out val);
                this.old_keybind = val.get_string();
                this.old_keybind_path = path;
                this.keybindings.set(iter, 1, "...");
                this.keybindings.get_value(iter, 2, out val);
                if ("guake-mode" == val.get_string()) {
                    Terminus.bindkey.unset_bindkey();
                    this.changing_guake = true;
                } else {
                    this.changing_guake = false;
                }
            }
        }

        public bool
        on_key_press(Gdk.EventKey eventkey)
        {
            if (this.editing_keybind == false) {
                return false;
            }

            switch (eventkey.keyval) {
            case Gdk.Key.Shift_L:
            case Gdk.Key.Shift_R:
            case Gdk.Key.Control_L:
            case Gdk.Key.Control_R:
            case Gdk.Key.Caps_Lock:
            case Gdk.Key.Shift_Lock:
            case Gdk.Key.Meta_L:
            case Gdk.Key.Meta_R:
            case Gdk.Key.Alt_L:
            case Gdk.Key.Alt_R:
            case Gdk.Key.Super_L:
            case Gdk.Key.Super_R:
            case Gdk.Key.ISO_Level3_Shift:
                return false;

            default:
                break;
            }

            this.editing_keybind = false;

            eventkey.state &= 0x07;

            if ((eventkey.keyval >= 97) && (eventkey.keyval <= 122)) {
                eventkey.keyval &= ~32;
            }

            var new_keybind = Gtk.accelerator_name(eventkey.keyval, eventkey.state);

            Gtk.TreeIter iter;
            Value        val;

            this.editing_keybind = false;
            this.keybindings.get_iter(out iter, this.old_keybind_path);
            this.keybindings.set(iter, 1, new_keybind);
            this.keybindings.get_value(iter, 2, out val);
            var key = val.get_string();
            Terminus.keybind_settings.set_string(key, new_keybind);

            return false;
        }
    }
}
