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


namespace Terminus {
    class HTMLColorButton : Object {
        private Gtk.ColorDialogButton color_button;
        private Gtk.CheckButton ?toggle_button;
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
            this.color_button = builder.get_object(color_button) as Gtk.ColorDialogButton;
            this.color_button.set_dialog(new Gtk.ColorDialog());
            if (enable_button != null) {
                this.toggle_button = builder.get_object(enable_button) as Gtk.CheckButton;
                this.enable_id = this.toggle_button.toggled.connect(() => {
                    this.set_status();
                });
            } else {
                this.toggle_button = null;
            }
            this.connect_id = this.color_button.notify.connect(() => {
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
                this.color_button.set_rgba(current_color);
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
                var rgba = this.color_button.get_rgba();
                Terminus.settings.set_string(this.property_name, "#%02X%02X%02X".printf((uint) (255 * rgba.red),
                                                                                        (uint) (255 * rgba.green),
                                                                                        (uint) (255 * rgba.blue)));
            }
        }

        public void
        set_rgba(Gdk.RGBA new_color)
        {
            this.color_button.set_rgba(new_color);
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
        private Gtk.CheckButton pointer_autohide;
        private Gtk.SpinButton scroll_value;
        private Gtk.FontDialogButton custom_font;

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

        private Gtk.ColorDialogButton[] palette_colors;

        private Gtk.DropDown color_scheme;
        private Gtk.StringList color_schemes;
        private Terminus.Terminuspalette[] colors;
        private Gtk.DropDown palette_scheme;
        private Gtk.StringList palette_schemes;
        private Terminus.Terminuspalette[] palettes;
        private Gtk.DropDown cursor_shape;
        private Gtk.Entry custom_shell;

        private GLib.ListStore keybindings_store;
        private Gtk.ColumnView keybindings_view;
        private Gtk.SingleSelection keybindings_model;
        private EditingKeybindMode editing_keybind;
        private bool changing_guake;
        private string old_keybind;
        private uint old_keybind_pos;
        private bool disable_palette_change;

        private Gtk.ColumnView macros_view;
        private GLib.ListStore macros_store;
        private Gtk.SingleSelection macros_model;
        private Gtk.Button add_macro;
        private Gtk.Button delete_macro;
        private Gtk.Entry macro_keybinding;
        private Gtk.Entry macro_command;


        public Properties()
        {
            this.editing_keybind = EditingKeybindMode.NONE;
            disable_palette_change = false;

            this.close_request.connect((w) => {
                this.hide();
                return true;
            });

            var      main_window = new Gtk.Builder();
            string[] elements = {
                "properties_notebook", "scroll_lines", "add_macro", "delete_macro"
            };
            main_window.add_objects_from_resource("/com/rastersoft/terminus/interface/properties.ui", elements);
            this.set_child(main_window.get_object("properties_notebook") as Gtk.Widget);

            var label_version = main_window.get_object("label_version") as Gtk.Label;
            label_version.label = _("Version %s").printf(Constants.VERSION);

            this.use_system_font = main_window.get_object("use_system_font") as Gtk.CheckButton;
            this.use_custom_shell = main_window.get_object("use_custom_shell") as Gtk.CheckButton;
            use_custom_shell.toggled.connect(() => {
                this.custom_shell.sensitive = this.use_custom_shell.active;
            });
            this.pointer_autohide = main_window.get_object("pointer_autohide") as Gtk.CheckButton;
            this.custom_font = main_window.get_object("custom_font") as Gtk.FontDialogButton;
            this.custom_font.set_dialog(new Gtk.FontDialog());
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
            this.color_scheme = main_window.get_object("color_scheme") as Gtk.DropDown;
            this.color_schemes = new Gtk.StringList(null);
            this.color_scheme.set_model(this.color_schemes);
            this.palette_scheme = main_window.get_object("palette_scheme") as Gtk.DropDown;
            this.palette_schemes = new Gtk.StringList(null);
            this.palette_scheme.set_model(this.palette_schemes);
            this.cursor_shape = main_window.get_object("cursor_shape") as Gtk.DropDown;
            this.macros_store = new GLib.ListStore(typeof(Gtk.StringList));
            this.macros_view = main_window.get_object("macros_view") as Gtk.ColumnView;
            this.macro_keybinding = main_window.get_object("macro_keybinding") as Gtk.Entry;
            this.macro_command = main_window.get_object("macro_command") as Gtk.Entry;
            this.add_macro = main_window.get_object("add_macro") as Gtk.Button;
            this.delete_macro = main_window.get_object("delete_macro") as Gtk.Button;

            this.macro_command.changed.connect(() => {
                this.update_macro_state();
            });
            this.macro_command.activate.connect(() => {
                this.add_macro_to_config();
            });
            this.macro_keybinding.changed.connect(() => {
                this.update_macro_state();
            });
            var focus_controller = new Gtk.EventControllerFocus();
            this.macro_keybinding.add_controller(focus_controller);
            focus_controller.enter.connect(() => {
                this.editing_keybind = EditingKeybindMode.MACRO;
            });
            var key_controller = new Gtk.EventControllerKey();
            this.macro_keybinding.add_controller(key_controller);
            key_controller.key_pressed.connect((controller, keyval, keycode, state) => {
                if (this.on_key_press(controller, keyval, keycode, state)) {
                    this.focus(DirectionType.RIGHT);
                }
                return true;
            });
            this.add_macro.clicked.connect(() => {
                this.add_macro_to_config();
            });
            this.delete_macro.clicked.connect(() => {
                var macro = this.macros_model.get_selected_item() as Gtk.StringList;
                if (macro == null) {
                    return;
                }
                GLib.Variant[] entries = {};
                foreach (var entry in Terminus.settings.get_value("macros")) {
                    if (entry.get_child_value(0).get_string() != macro.get_string(0)) {
                        entries += entry;
                    }
                }
                var new_settings = new GLib.Variant.array(new GLib.VariantType("(sss)"), entries);
                Terminus.settings.set_value("macros", new_settings);
                this.update_macros_list();
            });

            this.add_macro.sensitive = false;
            this.delete_macro.sensitive = false;

            this.palette_colors = {};
            string[] palette_string = Terminus.settings.get_strv("color-palete");
            var      tmpcolor = Gdk.RGBA();
            for (int i = 0; i < 16; i++) {
                Gtk.ColorDialogButton palette_button =
                    main_window.get_object("palette%d".printf(i)) as Gtk.ColorDialogButton;
                palette_button.set_dialog(new Gtk.ColorDialog());
                tmpcolor.parse(palette_string[i]);
                palette_button.set_rgba(tmpcolor);
                this.palette_colors += palette_button;
            }
            foreach (var button in this.palette_colors) {
                button.notify.connect(() => {
                    this.updated_palette();
                });
            }

            this.colors = {};
            foreach (var scheme in Terminus.main_root.palettes) {
                if ((!scheme.custom) && (scheme.text_fg == null)) {
                    continue;
                }
                this.color_schemes.append(scheme.name);
                colors += scheme;
            }
            this.color_scheme.set_selected(this.get_current_scheme());

            this.palettes = {};
            foreach (var scheme in Terminus.main_root.palettes) {
                if ((!scheme.custom) && (scheme.get_palette().length == 0)) {
                    continue;
                }
                this.palette_schemes.append(scheme.name);
                palettes += scheme;
            }

            this.palette_scheme.notify.connect((spec) => {
                if (spec.get_name() != "selected") {
                    return;
                }
                var selected = (int) this.palette_scheme.get_selected();
                var scheme = palettes[selected];
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

            this.color_scheme.notify.connect((spec) => {
                if (spec.get_name() != "selected") {
                    return;
                }
                var selected = (int) this.color_scheme.get_selected();
                var scheme = colors[selected];
                if (scheme.custom) {
                    return;
                }
                this.fg_color.set_rgba(scheme.text_fg);
                this.bg_color.set_rgba(scheme.text_bg);
            });

            this.fg_color.color_set.connect(() => {
                this.color_scheme.set_selected(this.get_current_scheme());
            });
            this.bg_color.color_set.connect(() => {
                this.color_scheme.set_selected(this.get_current_scheme());
            });

            var scroll_lines = main_window.get_object("scroll_lines") as Gtk.Adjustment;
            this.infinite_scroll = main_window.get_object("infinite_scroll") as Gtk.CheckButton;
            this.scroll_value = main_window.get_object("scroll_spinbutton") as Gtk.SpinButton;
            this.infinite_scroll.toggled.connect(() => {
                this.scroll_value.sensitive = !this.infinite_scroll.active;
            });

            this.enable_guake_mode = main_window.get_object("enable_guake_mode") as Gtk.CheckButton;

            this.custom_shell = main_window.get_object("command_shell") as Gtk.Entry;

            Terminus.settings.bind("cursor-shape", this.cursor_shape, "selected", GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("use-system-font", this.use_system_font, "active",
                                   GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.INVERT_BOOLEAN);
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
            Terminus.settings.bind("pointer-autohide", this.pointer_autohide, "active", GLib.SettingsBindFlags.DEFAULT);

            var                    system_font = Terminus.settings.get_boolean("use-system-font");
            Pango.FontDescription ?font_desc;
            if (system_font) {
                font_desc = null;
            } else {
                var font = Terminus.settings.get_string("terminal-font");
                font_desc = Pango.FontDescription.from_string(font);
            }
            this.custom_font.font_desc = font_desc;
            this.custom_font.notify.connect((spec) => {
                if (spec.get_name() != "font-desc") {
                    return;
                }
                Terminus.settings.set_string("terminal-font", this.custom_font.font_desc.to_string());
            });

            this.custom_shell.sensitive = this.use_custom_shell.active;
            this.custom_font.sensitive = this.use_system_font.active;
            this.scroll_value.sensitive = !this.infinite_scroll.active;

            this.palette_scheme.set_selected(this.get_current_palette());

            this.macros_model = new Gtk.SingleSelection(this.macros_store);
            this.update_macros_list();
            // Populate the macros Gtk.ColumnView
            var macro_factory = new Gtk.SignalListItemFactory();
            macro_factory.setup.connect((factory, object) => this.factory_setup(factory, object as Gtk.ListItem));
            macro_factory.bind.connect((factory, object) => this.factory_value_bind(factory, object as Gtk.ListItem,
                                                                                    0));
            var command_factory = new Gtk.SignalListItemFactory();
            command_factory.setup.connect((factory, object) => this.factory_setup(factory, object as Gtk.ListItem));
            command_factory.bind.connect((factory, object) => this.factory_value_bind(factory, object as Gtk.ListItem,
                                                                                      1));
            this.macros_view.set_model(this.macros_model);
            this.macros_view.append_column(new Gtk.ColumnViewColumn(_("Keybind"), macro_factory));
            this.macros_view.append_column(new Gtk.ColumnViewColumn(_("Command"), command_factory));

            this.keybindings_store = new GLib.ListStore(typeof(Gtk.StringList));
            this.keybindings_model = new Gtk.SingleSelection(this.keybindings_store);
            foreach (var kb in Terminus.key_bindings.key_binding_list) {
                var new_keybinding = new Gtk.StringList(null);
                new_keybinding.append(kb.description);
                new_keybinding.append(Terminus.keybind_settings.get_string(kb.name));
                new_keybinding.append(kb.name);
                this.keybindings_store.append(new_keybinding);
            }
            this.keybindings_view = main_window.get_object("keybindings") as Gtk.ColumnView;
            var keybindings_action_factory = new Gtk.SignalListItemFactory();
            keybindings_action_factory.setup.connect((factory, object) => this.factory_setup(factory,
                                                                                             object as Gtk.ListItem));
            keybindings_action_factory.bind.connect((factory, object) => this.factory_value_bind(factory,
                                                                                                 object as Gtk.ListItem,
                                                                                                 0));
            var keybindings_key_factory = new Gtk.SignalListItemFactory();
            keybindings_key_factory.setup.connect((factory, object) => this.factory_setup(factory,
                                                                                          object as Gtk.ListItem));
            keybindings_key_factory.bind.connect((factory, object) => this.factory_value_bind(factory,
                                                                                              object as Gtk.ListItem,
                                                                                              1));
            this.keybindings_view.set_model(this.keybindings_model);
            this.keybindings_view.append_column(new Gtk.ColumnViewColumn(_("Action"), keybindings_action_factory));
            this.keybindings_view.append_column(new Gtk.ColumnViewColumn(_("Key"), keybindings_key_factory));

            var controller = new Gtk.GestureClick();
            this.keybindings_view.add_controller(controller);
            controller.released.connect(() => { this.keybind_clicked_cb(); });

            var key_controller2 = new Gtk.EventControllerKey();
            keybindings_view.add_controller(key_controller2);
            key_controller2.key_pressed.connect((controller, keyval, keycode, state) => {
                this.on_key_press(controller, keyval, keycode, state);
                return false;
            });
        }

        private void
        factory_setup(Gtk.ListItemFactory factory,
                      Gtk.ListItem        item)
        {
            item.set_child(new Gtk.Label(""));
        }

        private void
        factory_value_bind(Gtk.ListItemFactory factory,
                           Gtk.ListItem        item,
                           int                 index)
        {
            var label = item.get_child() as Gtk.Label;
            var elements_list = item.get_item() as Gtk.StringList;
            label.set_label(elements_list.get_string(index));
            if (index == 0) {
                label.justify = Gtk.Justification.LEFT;
                label.halign = Gtk.Align.START;
            }
        }

        private void
        update_macros_list()
        {
            var macros = Terminus.settings.get_value("macros");
            this.macros_store.remove_all();
            foreach (var entry in macros) {
                var new_macro = new Gtk.StringList(null);
                new_macro.append(entry.get_child_value(0).get_string());
                new_macro.append(entry.get_child_value(1).get_string());
                this.macros_store.append(new_macro);
            }
            this.macro_keybinding.text = "";
            this.macro_command.text = "";
            this.update_macro_state();
        }

        private void
        add_macro_to_config()
        {
            var keybind = this.macro_keybinding.text;
            var command = this.macro_command.text;

            if ((keybind == "") || (command == "")) {
                return;
            }

            var new_entry = new GLib.Variant("(sss)", keybind, command, "");

            GLib.Variant[] entries = {};
            bool           found = false;
            foreach (var entry in Terminus.settings.get_value("macros")) {
                if (entry.get_child_value(0).get_string() == keybind) {
                    entries += new_entry;
                    found = true;
                } else {
                    entries += entry;
                }
            }
            if (found == false) {
                entries += new_entry;
            }
            var new_settings = new GLib.Variant.array(null, entries);
            Terminus.settings.set_value("macros", new_settings);
            this.macro_keybinding.text = "";
            this.macro_command.text = "";
            this.update_macros_list();
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
                var color = button.get_rgba();
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
                this.palette_scheme.set_selected(this.get_current_palette());
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
        update_macro_state()
        {
            if (this.macros_model.get_selected_item() == null) {
                this.delete_macro.sensitive = false;
            } else {
                this.delete_macro.sensitive = true;
            }

            if ((this.macro_command.text != "") && (this.macro_keybinding.text != "")) {
                this.add_macro.sensitive = true;
            } else {
                this.add_macro.sensitive = false;
            }
        }

        private void
        update_keybinding_entry(uint   position,
                                string new_text)
        {
            Gtk.StringList replacement[] = {
                new Gtk.StringList(null)
            };
            var            entry = keybindings_store.get_item(position) as Gtk.StringList;
            replacement[0].append(entry.get_string(0));
            replacement[0].append(new_text);
            replacement[0].append(entry.get_string(2));
            this.keybindings_store.splice(position, 1, replacement);
        }

        public void
        keybind_clicked_cb()
        {
            var selected = keybindings_model.get_selected_item() as Gtk.StringList;
            var position = keybindings_model.get_selected();

            if (this.editing_keybind != EditingKeybindMode.NONE) {
                this.editing_keybind = EditingKeybindMode.NONE;
                this.update_keybinding_entry(this.old_keybind_pos, this.old_keybind);
                if (this.changing_guake) {
                    Terminus.keybind_settings.set_string("guake-mode", old_keybind);
                }
            } else {
                this.editing_keybind = EditingKeybindMode.KEYBIND;
                this.old_keybind = selected.get_string(1);
                this.old_keybind_pos = position;
                this.update_keybinding_entry(position, " ");
                if ("guake-mode" == selected.get_string(2)) {
                    this.changing_guake = true;
                } else {
                    this.changing_guake = false;
                }
            }
        }

        public bool
        on_key_press(Gtk.EventControllerKey key_controller,
                     uint                   keyval,
                     uint                   keycode,
                     Gdk.ModifierType       state)
        {
            if (this.editing_keybind == EditingKeybindMode.NONE) {
                return false;
            }

            switch (keyval) {
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

            // avoid mod2 and other odd mods
            state &= Gdk.ModifierType.SHIFT_MASK |
                     Gdk.ModifierType.CONTROL_MASK |
                     Gdk.ModifierType.SUPER_MASK |
                     Gdk.ModifierType.META_MASK |
                     Gdk.ModifierType.HYPER_MASK |
                     Gdk.ModifierType.ALT_MASK;

            if ((keyval >= 'a') && (keyval <= 'z')) {
                keyval &= ~32;
            }

            var new_keybind = Gtk.accelerator_name(keyval, state);

            if (this.editing_keybind == EditingKeybindMode.KEYBIND) {
                var keybind = this.keybindings_model.get_selected_item() as Gtk.StringList;
                var key = keybind.get_string(2);
                Terminus.keybind_settings.set_string(key, new_keybind);
                this.update_keybinding_entry(this.old_keybind_pos, new_keybind);
            } else {
                // macro
                this.macro_keybinding.text = new_keybind;
            }

            this.editing_keybind = EditingKeybindMode.NONE;
            return true;
        }
    }
}
