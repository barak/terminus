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

namespace Terminus {

	class Fixed : Gtk.Fixed {

		public override void get_preferred_width (out int minimum_width, out int natural_width) {
			minimum_width = 1;
			natural_width = 1;
		}

		public override void get_preferred_height (out int minimum_height, out int natural_height) {
			minimum_height = 1;
			natural_height = 1;
		}
	}

	class Window : Gtk.Window {

		public signal void ended(Terminus.Window window);
		public signal void new_window();

		private int current_size;
		private int mouseY;
		private Gtk.Paned paned;
		private Terminus.Fixed fixed;
		private bool is_guake;

		private Terminus.Base terminal;
		private int initialized;

		public Window(bool guake_mode, Terminus.Base? terminal = null) {

			this.is_guake = guake_mode;
			this.initialized = 0;

			this.type_hint = Gdk.WindowTypeHint.NORMAL;
			this.focus_on_map = true;

			this.destroy.connect( (w) => {
				this.ended(this);
			});

			if (terminal == null) {
				this.terminal = new Terminus.Base();
			} else {
				this.terminal = terminal;
			}
			this.terminal.ended.connect(this.ended_cb);

			this.terminal.new_window.connect( () => {
				this.new_window();
			});

			if (guake_mode) {
				var scr = this.get_screen();
				this.current_size = Terminus.settings.get_int("guake-height");
				if (this.current_size < 0) {
					this.current_size = scr.get_height() * 3 / 7;
					Terminus.settings.set_int("guake-height", this.current_size);
				}
				this.move(0,0);

				this.map.connect(this.mapped);
				this.paned = new Gtk.Paned(Gtk.Orientation.VERTICAL);
				this.paned.wide_handle = true;
				this.paned.events = Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.POINTER_MOTION_MASK|Gdk.EventMask.LEAVE_NOTIFY_MASK;
				this.add(this.paned);
				this.paned.add1(this.terminal);
				this.fixed = new Terminus.Fixed();
				//this.fixed.set_size_request(1,1);
				this.paned.add2(fixed);
				this.mouseY = -1;

				this.paned.motion_notify_event.connect( (widget,event) => {
					if (this.mouseY < 0) {
						return false;
					}

					if ((event.state & Gdk.ModifierType.BUTTON1_MASK) == 0) {
						this.mouseY = -1;
						Terminus.settings.set_int("guake-height", this.current_size);
						return false;
					}

					int y;
					y = (int)(event.y_root);
					int newval = y - this.mouseY;
					this.current_size += newval;
					this.mouseY = y;
					this.resize(this.get_screen().get_width(),this.current_size);
					this.paned.set_position(this.current_size);
					return true;
				});

				this.paned.button_press_event.connect( (widget, event) => {
					if (event.button != 1) {
						return false;
					}
					int y;
					y = (int)(event.y_root);
					this.mouseY = y;
					return true;
				});

				this.paned.button_release_event.connect( (widget,event) => {
					if (event.button != 1) {
						return false;
					}
					this.mouseY = -1;
					Terminus.settings.set_int("guake-height", this.current_size);
					return true;
				});

				this.paned.show_all();
				this.mapped();
			} else {
				this.add(this.terminal);
				this.terminal.show_all();
				this.present();
			}
		}

		public override void get_preferred_width (out int minimum_width, out int natural_width) {
			if ((this.is_guake) && (this.mouseY < 0)) {
				var scr = this.get_screen();
				minimum_width = scr.get_width();
				natural_width = scr.get_width();
			} else {
				this.terminal.get_preferred_width(out minimum_width, out natural_width);
			}
		}

		public override void get_preferred_height (out int minimum_height, out int natural_height) {
			if ((this.is_guake) && (this.mouseY < 0)) {
				var scr = this.get_screen();
				this.current_size = Terminus.settings.get_int("guake-height");
				if (this.current_size < 0) {
					this.current_size = scr.get_height() * 3 / 7;
					Terminus.settings.set_int("guake-height", this.current_size);
				}
				minimum_height = this.current_size;
				natural_height = this.current_size;
			} else {
				this.terminal.get_preferred_height(out minimum_height, out natural_height);
			}
		}

		public void ended_cb() {

			this.terminal.ended.disconnect(this.ended_cb);
			this.destroy();
		}

		public void mapped() {
			this.stick();
			this.set_keep_above(true);
			this.set_skip_taskbar_hint(true);
			this.set_skip_pager_hint(true);
			this.set_decorated(false);
			if (this.initialized == 0) {
				this.paned.set_position(this.current_size);
			} else if (this.initialized == 1) {
				this.resize(this.get_screen().get_width(),this.current_size);
			}
			this.initialized++;
		}

	}
}
