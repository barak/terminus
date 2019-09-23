/*
 * Copyright 2016 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Terminus
 *
 * Terminus is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Terminus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Gee;

//project version = 1.6.0

namespace Terminus {
	TerminusRoot     main_root;
	GLib.Settings    settings         = null;
	GLib.Settings    keybind_settings = null;
	Terminus.Bindkey bindkey;
	Parameters       parameters = null;
	int tid_counter             = 0;

	class Terminuspalette : Object {
		public bool custom;
		public string ? name;
		public HashMap<string, string> name_locale;
		public Gdk.RGBA[] palette;
		public Gdk.RGBA ? text_fg;
		public Gdk.RGBA ? text_bg;


		public Terminuspalette() {
			this.name        = null;
			this.palette     = {};
			this.text_fg     = null;
			this.text_bg     = null;
			this.name_locale = new HashMap<string, string> ();
			this.custom      = false;
		}

		public bool compare_scheme() {
			if (this.custom) {
				return false;
			}

			if (this.text_fg == null) {
				return false;
			}

			var color = Gdk.RGBA();

			color.parse(Terminus.settings.get_string("fg-color"));
			if (!this.text_fg.equal(color)) {
				return false;
			}
			color.parse(Terminus.settings.get_string("bg-color"));
			if (!this.text_bg.equal(color)) {
				return false;
			}

			return true;
		}

		public bool compare_palette() {
			string[] current = Terminus.settings.get_strv("color-palete");
			if (current.length != this.palette.length) {
				return false;
			}
			for (int i = 0; i < 16; i++) {
				string color = "#%02X%02X%02X".printf((int) (this.palette[i].red * 255), (int) (this.palette[i].green * 255), (int) (this.palette[i].blue * 255));
				if (current[i].ascii_up() != color) {
					return false;
				}
			}
			return true;
		}

		public bool readpalette(string filename) {
			if (!filename.has_suffix(".color_scheme")) {
				return true;
			}

			var file = File.new_for_path(filename);

			if (!file.query_exists()) {
				return true;
			}
			bool has_more  = false;
			int  line_n    = 0;
			bool has_error = false;
			try {
				var    dis = new DataInputStream(file.read());
				string line;
				while ((line = dis.read_line(null)) != null) {
					line_n++;
					line = line.strip();
					if (line.length == 0) {
						continue;
					}
					if (line[0] == '#') {
						continue;
					}
					var pos = line.index_of_char(':');
					if (pos == -1) {
						GLib.stderr.printf(_("Error: palette file %s has unrecognized content at line %d\n"), filename, line_n);
						has_error = true;
						continue;
					}
					var command = line.substring(0, pos).strip();
					var sdata   = line.substring(pos + 1).strip();
					if (command == "name") {
						this.name = sdata;
						continue;
					}
					if (command.has_prefix("name[")) {
						var p = command.index_of_char(']');
						if (p == -1) {
							GLib.stderr.printf(_("Error: palette file %s has opens a bracket at line %d without closing it\n"), filename, line_n);
							has_error = true;
							continue;
						}
						var lang = command.substring(5, p - 5);
						this.name_locale[lang] = sdata;
						continue;
					}
					if (sdata[0] != '#') {
						sdata = "#" + sdata;
					}
					var data = Gdk.RGBA();
					if (!data.parse(sdata)) {
						GLib.stderr.printf(_("Error: palette file %s has an unrecognized color at line %d\n"), filename, line_n);
						has_error = true;
						continue;
					}
					switch (command) {
					case "palette":
						if (this.palette.length < 16) {
							this.palette += data;
						} else {
							if (!has_more) {
								GLib.stderr.printf(_("Warning: palette file %s has more than 16 colors\n"), filename);
							}
							has_more = true;
						}
						break;

					case "text_fg":
						this.text_fg = data;
						break;

					case "text_bg":
						this.text_bg = data;
						break;

					default:
						GLib.stderr.printf(_("Error: palette file %s has unrecognized content at line %d\n"), filename, line_n);
						has_error = true;
						break;
					}
				}
			} catch (Error e) {
				return true;
			}

			if ((this.palette.length > 0) && (this.palette.length < 16)) {
				GLib.stdout.printf(_("Error: Palette file %s has less than 16 colors\n"), filename);
				has_error = true;
			}
			if ((this.name == null) || (this.name == "")) {
				GLib.stdout.printf(_("Error: Palette file %s has no palette name\n"), filename);
				has_error = true;
			}
			if ((this.text_bg == null) && (this.text_fg != null)) {
				GLib.stdout.printf(_("Error: Palette file %s has text_fg color but not text_bg color\n"), filename);
				has_error = true;
			}
			if ((this.text_bg != null) && (this.text_fg == null)) {
				GLib.stdout.printf(_("Error: Palette file %s has text_bg color but not text_fg color\n"), filename);
				has_error = true;
			}

			foreach (var locale in GLib.Intl.get_language_names()) {
				if (this.name_locale.has_key(locale)) {
					this.name = this.name_locale.get(locale);
					break;
				}
			}
			return has_error;
		}
	}

	class TerminusRoot : Object {
		private Gee.List<Terminus.Window> window_list;
		private bool launch_guake;
		private bool check_guake;
		private Terminus.Base ? guake_terminal;
		private Terminus.Window ? guake_window;
		private bool ready;
		private int extcall;
		private string ? guake_title;

		private bool tmp_launch_terminal;
		private bool tmp_launch_guake;

		public Gee.List<Terminuspalette> palettes;

		public Terminus.Properties window_properties;

		public TerminusRoot(string[] argv) {
			this.ready           = false;
			this.extcall         = -1;
			main_root            = this;
			this.guake_terminal  = null;
			this.guake_window    = null;
			this.guake_title     = null;

			bool binded_key = Terminus.bindkey.set_bindkey(Terminus.keybind_settings.get_string("guake-mode"));

			this.window_list = new Gee.ArrayList<Terminus.Window>();

			this.launch_guake = parameters.launch_guake;
			this.check_guake  = parameters.check_guake;
			this.guake_title  = parameters.UUID;

			this.tmp_launch_terminal = true;
			this.tmp_launch_guake    = false;

			this.palettes = new Gee.ArrayList<Terminuspalette>();

			this.read_color_schemes(GLib.Path.build_filename(Constants.DATADIR, "terminus"));
			this.read_color_schemes(GLib.Path.build_filename(Environment.get_home_dir(), ".local", "share", "terminus"));
			var palette = new Terminuspalette();
			palette.custom = true;
			palette.name   = _("Custom colors");
			this.palettes.sort(this.ComparePalettes);
			this.palettes.add(palette);

			this.window_properties = new Terminus.Properties();

			if (binded_key) {
				this.tmp_launch_guake = Terminus.settings.get_boolean("enable-guake-mode");;
			} else {
				this.tmp_launch_guake = false;
			}

			if (this.launch_guake) {
				this.tmp_launch_terminal = false;
				this.check_guake         = false;
			}

			if (this.check_guake) {
				this.tmp_launch_terminal = false;
				this.tmp_launch_guake    = Terminus.settings.get_boolean("enable-guake-mode");
			}

			if (this.tmp_launch_terminal || this.tmp_launch_guake) {
				Bus.own_name(BusType.SESSION, "com.rastersoft.terminus", BusNameOwnerFlags.NONE, this.on_bus_aquired, () => {
					// if there is no other Terminus process, we are responsible for everything
					if (this.tmp_launch_terminal) {
					    this.create_window(false);
					}
					this.tmp_launch_terminal = false;
					if (this.tmp_launch_guake) {
					    this.create_window(true);
					}
					this.tmp_launch_guake = false;
					Terminus.keybind_settings.changed.connect(this.keybind_settings_changed);
					this.ready = true;
					if (this.extcall != -1) {
					    show_hide_global(this.extcall);
					}
				}, () => {
					// if we are checking to launch guake, and there is already a process, return an error
					if (this.check_guake) {
						Posix.exit(1);
					}
					// if there is another Terminus process, ask it to open a new window and exit
					RemoteControlInterface server = Bus.get_proxy_sync(BusType.SESSION, "com.rastersoft.terminus", "/com/rastersoft/terminus");
					if (this.tmp_launch_terminal) {
					    int tid;
					    server.show_terminal(parameters.command, out tid);
					}
					Gtk.main_quit();
				});
				Gtk.main();
			}
		}

		public int ComparePalettes(Terminuspalette a, Terminuspalette b) {
			if (a.name < b.name) {
				return -1;
			} else {
				if (a.name > b.name) {
					return 1;
				} else {
					return 0;
				}
			}
		}

		void read_color_schemes(string foldername) {
			try {
				var directory = File.new_for_path(foldername);

				var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);

				FileInfo file_info;
				while ((file_info = enumerator.next_file()) != null) {
					var palette = new Terminuspalette();
					if (!palette.readpalette(GLib.Path.build_filename(foldername, file_info.get_name()))) {
						this.palettes.add(palette);
					}
				}
			} catch (Error e) {
			}
		}

		void on_bus_aquired(DBusConnection conn) {
			try {
				conn.register_object("/com/rastersoft/terminus", new RemoteControl());
			} catch (IOError e) {
				GLib.stderr.printf("Could not register service\n");
			}
		}

		public void keybind_settings_changed(string key) {
			if (key != "guake-mode") {
				return;
			}
			Terminus.bindkey.show_guake.disconnect(this.show_hide);
			Terminus.bindkey.set_bindkey(Terminus.keybind_settings.get_string("guake-mode"));
			Terminus.bindkey.show_guake.connect(this.show_hide);
		}

		public int create_window(bool guake_mode) {
			Terminus.Window window;

			if (guake_mode) {
				if (this.guake_terminal == null) {
					this.guake_terminal = new Terminus.Base();
				}
				window            = new Terminus.Window(true, tid_counter, this.guake_terminal, this.guake_title);
				this.guake_window = window;
				Terminus.bindkey.show_guake.connect(this.show_hide);
			} else {
				window = new Terminus.Window(false, tid_counter);
			}
			tid_counter++;

			window.ended.connect((w) => {
				window_list.remove(w);
				if (w == this.guake_window) {
				    Terminus.bindkey.show_guake.disconnect(this.show_hide);
				    this.guake_window   = null;
				    this.guake_terminal = null;
				    this.create_window(true);
				}
				if (window_list.size == 0) {
				    Gtk.main_quit();
				}
			});
			window.new_window.connect(() => {
				this.create_window(false);
			});
			window_list.add(window);
			return window.terminal_id;
		}

		public void show_hide() {
			this.show_hide_global(2);
		}

		public void show_hide_global(int mode) {
			/* mode = 0: force show
			 * mode = 1: force hide
			 * mode = 2: hide if visible, show if hidden
			 */

			if (!this.ready) {
				this.extcall = mode;
				return;
			}

			if (Terminus.settings.get_boolean("enable-guake-mode") == false) {
				return;
			}

			if (this.guake_window == null) {
				this.create_window(true);
			}

			if (mode == 0) {
				if (!this.guake_window.visible) {
					this.guake_window.show();
				}
				return;
			}

			if (mode == 1) {
				if (this.guake_window.visible) {
					this.guake_window.hide();
				}
				return;
			}

			// mode 2
			if (this.guake_window.visible) {
				this.guake_window.hide();
			} else {
				this.guake_window.present();
			}
		}
	}

	/**
	 * Ensures that the palette stored in the settings is valid
	 * If not, replaces the ofending elements
	 */
	bool check_palette() {
		string[] palette_string = Terminus.settings.get_strv("color-palete");
		if (palette_string.length != 16) {
			string[] tmp = {};
			for (var i = 0; i < 16; i++) {
				var color = Gdk.RGBA();
				if ((i < palette_string.length) && (color.parse(palette_string[i]))) {
					tmp += palette_string[i];
				} else {
					var v = (i < 8) ? 0xAA : 0xFF;
					tmp += "#%02X%02X%02X".printf(((v & 0x01) != 0 ? v : 0), ((v & 0x02) != 0 ? v : 0), ((v & 0x04) != 0 ? v : 0));
				}
			}
			Terminus.settings.set_strv("color-palete", tmp);
			return true;
		}
		return false;
	}

	[DBus(name = "com.rastersoft.terminus")]
	public class RemoteControl : GLib.Object {
		public int do_ping(int v) throws GLib.Error, GLib.DBusError {
			return (v + 1);
		}

		public void disable_keybind() throws GLib.Error, GLib.DBusError {
			bindkey.unset_bindkey();
		}

		public void show_guake() throws GLib.Error, GLib.DBusError {
			main_root.show_hide_global(0);
		}

		public void hide_guake() throws GLib.Error, GLib.DBusError {
			main_root.show_hide_global(1);
		}

		public void swap_guake() throws GLib.Error, GLib.DBusError {
			main_root.show_hide_global(2);
		}

		public void show_terminal(string[] argv, out int tid) throws GLib.Error, GLib.DBusError {
			parameters.command = argv;
			tid = main_root.create_window(false);
		}
	}

	[DBus(name = "com.rastersoft.terminus")]
	public interface RemoteControlInterface : GLib.Object {
		public abstract int do_ping(int v) throws GLib.Error, GLib.DBusError;

		public abstract void disable_keybind() throws GLib.Error, GLib.DBusError;

		public abstract void show_guake() throws GLib.Error, GLib.DBusError;

		public abstract void hide_guake() throws GLib.Error, GLib.DBusError;

		public abstract void swap_guake() throws GLib.Error, GLib.DBusError;

		public abstract void show_terminal(string[] argv, out int tid) throws GLib.Error, GLib.DBusError;
	}
}

int main(string[] argv) {
	Intl.bindtextdomain(Constants.GETTEXT_PACKAGE, GLib.Path.build_filename(Constants.DATADIR, "locale"));

	Intl.textdomain(Constants.GETTEXT_PACKAGE);
	Intl.bind_textdomain_codeset(Constants.GETTEXT_PACKAGE, "UTF-8");

	Gtk.init(ref argv);

	Terminus.parameters       = new Terminus.Parameters(argv);
	Terminus.settings         = new GLib.Settings("org.rastersoft.terminus");
	Terminus.keybind_settings = new GLib.Settings("org.rastersoft.terminus.keybindings");
	Terminus.bindkey          = new Terminus.Bindkey(Terminus.parameters.bind_keys);

	Terminus.check_palette();

	new Terminus.TerminusRoot(argv);

	return 0;
}
