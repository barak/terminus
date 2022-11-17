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

using Vte;
using Gtk;
using Gdk;

namespace Terminus {
    /**
     * This is the widget put in each tab
     */

    class Notetab : Gtk.EventBox, Killable {
        private Terminus.Container top_container;
        private Gtk.Label title;
        private Terminus.Base main_container;
        private Gtk.Box inner_box;

        public Notetab(Terminus.Base      main_container,
                       Terminus.Container top_container)
        {
            this.main_container = main_container;
            this.top_container = top_container;
            this.inner_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.title = new Gtk.Label("");
            this.title.margin_end = 3;
            var close_button = new Gtk.Button.from_icon_name("window-close");
            this.inner_box.pack_start(this.title, true, true);
            this.inner_box.pack_start(close_button, false, true);
            this.add(this.inner_box);
            this.show_all();
            close_button.clicked.connect(() => {
                this.close_tab();
            });
            this.add_events(Gdk.EventMask.BUTTON_RELEASE_MASK);
            this.button_release_event.connect((event) => {
                if (event.button == 2) {
                    this.close_tab();
                    return true;
                }
                return false;
            });
        }

        private void
        close_tab()
        {
            if (this.top_container.check_if_running_processes()) {
                this.main_container.ask_kill_childs(_("This tab has running processes."),
                                                    _("Closing it will kill them."),
                                                    _("Close tab"), this);
            } else {
                this.kill_all_children();
            }
        }

        public void
        kill_all_children()
        {
            this.main_container.delete_page(this.top_container);
        }

        public void
        change_title(string new_title)
        {
            this.title.label = new_title;
        }
    }
}
