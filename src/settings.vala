/*
 Copyright 2016 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Terminus

 Terminus is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Terminus is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using Gtk;
using Gdk;

namespace Terminus {

	struct ColorScheme {

		string name;
		uint8 fg_red;
		uint8 fg_green;
		uint8 fg_blue;
		uint8 bg_red;
		uint8 bg_green;
		uint8 bg_blue;

		public ColorScheme(string name, uint8 fg_red, uint8 fg_green, uint8 fg_blue, uint8 bg_red, uint8 bg_green, uint8 bg_blue) {
			this.name = name;
			this.fg_red = fg_red;
			this.fg_green = fg_green;
			this.fg_blue = fg_blue;
			this.bg_red = bg_red;
			this.bg_green = bg_green;
			this.bg_blue = bg_blue;
		}

	}

	class Properties : Gtk.Window {

		private Gtk.CheckButton use_system_font;
		private Gtk.CheckButton infinite_scroll;
		private Gtk.CheckButton enable_guake_mode;
		private Gtk.SpinButton scroll_value;
		private Gtk.Button custom_font;
		private Gtk.ColorButton fg_color;
		private Gtk.ColorButton bg_color;
		private Gtk.ComboBox color_scheme;
		private ColorScheme[] schemes;
		private Gtk.ListStore keybindings;

		private bool editing_keybind;
		private bool changing_guake;
		private string old_keybind;
		private Gtk.TreePath old_keybind_path;

		public Properties() {

			this.editing_keybind = false;

			this.schemes = {
				ColorScheme(_("Custom colors"),0x00,0x00,0x00,0x00,0x00,0x00),
				ColorScheme(_("Black on light yellow"),0x00,0x00,0x00,0xFF,0xFF,0xDD),
				ColorScheme(_("Black on white"),0x00,0x00,0x00,0xFF,0xFF,0xFF),
				ColorScheme(_("Gray on black"),0xC0,0xC0,0xC0,0x00,0x00,0x00),
				ColorScheme(_("Green on black"),0x0F,0xF7,0x7F,0x00,0x00,0x00),
				ColorScheme(_("Orange on black"),0xFE,0xCE,0x12,0x00,0x00,0x00),
				ColorScheme(_("White on black"),0xFF,0xFF,0xFF,0x00,0x00,0x00)
			};

			this.delete_event.connect( (w) => {
				this.hide();
				return true;
			});

			var main_window = new Gtk.Builder();
			string[] elements = {"properties_notebook", "list_schemes", "scroll_lines", "transparency_level"};
			main_window.add_objects_from_resource("/com/rastersoft/terminus/interface/properties.ui",elements);
			this.add(main_window.get_object("properties_notebook") as Gtk.Widget);

			this.use_system_font = main_window.get_object("use_system_font") as Gtk.CheckButton;
			this.custom_font =  main_window.get_object("custom_font") as Gtk.Button;
			use_system_font.toggled.connect( () => {
				this.custom_font.sensitive = !this.use_system_font.active;
			});

			this.fg_color = main_window.get_object("text_color") as Gtk.ColorButton;
			this.fg_color.color_set.connect( () => {
				var color = (this.fg_color as Gtk.ColorChooser).rgba;
				var htmlcolor = "#%02X%02X%02X".printf((uint)(255*color.red),(uint)(255*color.green),(uint)(255*color.blue));
				Terminus.settings.set_string("fg-color",htmlcolor);
			});
			this.bg_color = main_window.get_object("bg_color") as Gtk.ColorButton;
			this.bg_color.color_set.connect( () => {
				var color = (this.bg_color as Gtk.ColorChooser).rgba;
				var htmlcolor = "#%02X%02X%02X".printf((uint)(255*color.red),(uint)(255*color.green),(uint)(255*color.blue));
				Terminus.settings.set_string("bg-color",htmlcolor);
			});

			this.color_scheme = main_window.get_object("color_scheme") as Gtk.ComboBox;
			this.color_scheme.changed.connect( () => {
				var selected = this.color_scheme.get_active();
				if (selected == 0) { // Custom
					this.fg_color.sensitive = true;
					this.bg_color.sensitive = true;
					var color = (this.fg_color as Gtk.ColorChooser).rgba;
					var htmlcolor = "#%02X%02X%02X".printf((uint)(255*color.red),(uint)(255*color.green),(uint)(255*color.blue));
					Terminus.settings.set_string("fg-color",htmlcolor);
					color = (this.bg_color as Gtk.ColorChooser).rgba;
					htmlcolor = "#%02X%02X%02X".printf((uint)(255*color.red),(uint)(255*color.green),(uint)(255*color.blue));
					Terminus.settings.set_string("bg-color",htmlcolor);
				} else {
					this.fg_color.sensitive = false;
					this.bg_color.sensitive = false;
					var fg_htmlcolor = "#%02X%02X%02X".printf(this.schemes[selected].fg_red,this.schemes[selected].fg_green,this.schemes[selected].fg_blue);
					var bg_htmlcolor = "#%02X%02X%02X".printf(this.schemes[selected].bg_red,this.schemes[selected].bg_green,this.schemes[selected].bg_blue);
					Terminus.settings.set_string("fg-color",fg_htmlcolor);
					Terminus.settings.set_string("bg-color",bg_htmlcolor);
				}
			});

			var scroll_lines = main_window.get_object("scroll_lines") as Gtk.Adjustment;
			this.infinite_scroll = main_window.get_object("infinite_scroll") as Gtk.CheckButton;
			this.scroll_value = main_window.get_object("scroll_spinbutton") as Gtk.SpinButton;
			this.infinite_scroll.toggled.connect( () => {
				this.scroll_value.sensitive = !this.infinite_scroll.active;
			});

			this.enable_guake_mode = main_window.get_object("enable_guake_mode") as Gtk.CheckButton;

			Terminus.settings.bind("color-scheme",this.color_scheme,"active",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("use-system-font",this.use_system_font,"active",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("terminal-font",this.custom_font,"font_name",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("scroll-lines",scroll_lines,"value",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("infinite-scroll",this.infinite_scroll,"active",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("scroll-on-output",main_window.get_object("scroll_on_output") as Gtk.CheckButton,"active",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("scroll-on-keystroke",main_window.get_object("scroll_on_keystroke") as Gtk.CheckButton,"active",GLib.SettingsBindFlags.DEFAULT);
			Terminus.settings.bind("enable-guake-mode",this.enable_guake_mode,"active",GLib.SettingsBindFlags.DEFAULT);


			var list_schemes = main_window.get_object("list_schemes") as Gtk.ListStore;
			int counter = 0;
			foreach(var scheme in this.schemes) {
				Gtk.TreeIter iter;
				list_schemes.append(out iter);
				var name = GLib.Value(typeof(string));
				name.set_string(scheme.name);
				list_schemes.set_value(iter,0,name);
				var id = GLib.Value(typeof(int));
				id.set_int(counter);
				list_schemes.set_value(iter,1,id);
				counter++;
			}

			this.custom_font.sensitive = !this.use_system_font.active;
			this.scroll_value.sensitive = !this.infinite_scroll.active;
			var fg_color = Gdk.RGBA();
			var bg_color = Gdk.RGBA();
			fg_color.parse(Terminus.settings.get_string("fg-color"));
			bg_color.parse(Terminus.settings.get_string("bg-color"));
			this.fg_color.set_rgba(fg_color);
			this.bg_color.set_rgba(bg_color);
			this.color_scheme.set_active(Terminus.settings.get_int("color-scheme"));

			this.keybindings = new Gtk.ListStore(3, typeof(string), typeof(string), typeof(string));
			this.add_keybinding(_("New window"),"new-window");
			this.add_keybinding(_("New tab"),"new-tab");
			this.add_keybinding(_("Next tab"),"next-tab");
			this.add_keybinding(_("Previous tab"),"previous-tab");
			this.add_keybinding(_("Show guake terminal"),"guake-mode");

			var keybindings_view = main_window.get_object("keybindings") as Gtk.TreeView;
			keybindings_view.activate_on_single_click = true;
			keybindings_view.row_activated.connect(this.keybind_clicked_cb);
			keybindings_view.set_model(this.keybindings);
			Gtk.CellRendererText cell = new Gtk.CellRendererText ();
			keybindings_view.insert_column_with_attributes (-1, _("Action"), cell, "text", 0);
			keybindings_view.insert_column_with_attributes (-1, _("Key"), cell, "text", 1);

			this.events = Gdk.EventMask.KEY_PRESS_MASK;
			this.key_press_event.connect(this.on_key_press);

			Terminus.bindkey.set_bindkey(Terminus.keybind_settings.get_string("guake-mode"));
		}

		private void add_keybinding(string name, string setting) {
			Gtk.TreeIter iter;
			this.keybindings.append(out iter);
			this.keybindings.set(iter,0,name,1,Terminus.keybind_settings.get_string(setting),2,setting);
		}

		public void keybind_clicked_cb(TreePath path, TreeViewColumn column) {
			Gtk.TreeIter iter;
			Value val;

			if (this.editing_keybind) {
				this.editing_keybind = false;
				this.keybindings.get_iter(out iter,this.old_keybind_path);
				this.keybindings.set(iter,1,this.old_keybind);
				if (this.changing_guake) {
					Terminus.bindkey.set_bindkey(this.old_keybind);
				}
			} else {
				this.editing_keybind = true;
				this.keybindings.get_iter(out iter,path);
				this.keybindings.get_value(iter,1,out val);
				this.old_keybind = val.get_string();
				this.old_keybind_path = path;
				this.keybindings.set(iter,1,"...");
				this.keybindings.get_value(iter,2,out val);
				if ("guake-mode" == val.get_string()) {
					Terminus.bindkey.unset_bindkey();
					this.changing_guake = true;
				} else {
					this.changing_guake = false;
				}
			}
		}

		public bool on_key_press(Gdk.EventKey eventkey) {

			if (this.editing_keybind == false) {
				return false;
			}

			switch(eventkey.keyval) {
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

			if (eventkey.keyval < 128) {
				eventkey.keyval |= 32;
			}

			var new_keybind = Gtk.accelerator_name(eventkey.keyval,eventkey.state);

			Gtk.TreeIter iter;
			Value val;

			this.editing_keybind = false;
			this.keybindings.get_iter(out iter,this.old_keybind_path);
			this.keybindings.set(iter,1,new_keybind);
			if (this.changing_guake) {
				Terminus.bindkey.set_bindkey(new_keybind);
			}

			this.keybindings.get_value(iter,2,out val);
			var key = val.get_string();
			Terminus.keybind_settings.set_string(key,new_keybind);

			return false;
		}
	}
}