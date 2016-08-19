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

using Vte;
using Gtk;

namespace Terminus {

	/**
	 * This is the main class, that contains everything. This class must be
	 * enclosed in a window.
	 */

	class Base : Gtk.Notebook {

		public static GLib.Settings settings = null;
		public static GLib.Settings keybind_settings = null;
		public static Terminus.Properties window_properties;

		public signal void ended();
		public signal void new_window();

		public Base() {

			Terminus.Base.settings = new GLib.Settings("org.rastersoft.terminus");
			Terminus.Base.keybind_settings = new GLib.Settings("org.rastersoft.terminus.keybindings");
			Terminus.Base.window_properties = new Terminus.Properties(Terminus.Base.settings,Terminus.Base.keybind_settings);
			this.page_added.connect(this.check_pages);
			this.page_removed.connect(this.check_pages);
			this.new_terminal_tab();
		}

		public void new_terminal_tab() {

			var term = new Terminus.Container(this,null);
			term.ended.connect( (w) => {
				this.delete_page(term);
			});
			term.show_all();
			var page = this.append_page(term,term.notetab);
			this.set_current_page(page);
		}

		public void new_terminal_window() {
			this.new_window();
		}

		public void delete_page(Terminus.Container top_container) {
			var page = this.page_num(top_container);
			if (page != -1) {
				this.remove_page(page);
			}
		}

		public void check_pages(Gtk.Widget child, uint page_num) {

			var npages = this.get_n_pages();
			if (npages == 0) {
				this.ended();
			}
			if (npages <= 1) {
				this.show_tabs = false;
			} else {
				this.show_tabs = true;
			}
		}
	}
}
