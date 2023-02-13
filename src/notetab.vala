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
using Pango;

namespace Terminus {
    /**
     * This is the widget put in each tab
     */

    public class Notetab : Gtk.EventBox, Killable, DnDDestination {
        private Terminus.Container top_container;
        private Gtk.Label title;
        private Terminus.Base main_container;
        private Gtk.Box inner_box;
        private uint timeout_id;

        public Notetab(Terminus.Base      main_container,
                       Terminus.Container top_container)
        {
            this.main_container = main_container;
            this.top_container = top_container;
            this.top_container.close_tab.connect(() => {
                this.close_tab();
            });
            this.timeout_id = 0;
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
            this.drag_motion.connect(this.motion);
            this.drag_leave.connect(this.leave);
            Gtk.drag_dest_set(this, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, null,
                              Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.DEFAULT);
            Gtk.drag_dest_set_target_list(this, dnd_manager.targets);
            this.drag_drop.connect((widget, context, x, y, time) => {
                Terminus.dnd_manager.set_destination(this);
                return true;
            });
        }

        public void
        drop_terminal(Terminal terminal)
        {
            this.main_container.new_terminal_tab("", null, terminal);
        }

        public bool
        accepts_drop(Terminal terminal)
        {
            return true;
        }

        private void
        close_tab()
        {
            if (this.top_container.check_if_running_processes()) {
                this.main_container.ask_kill_childs(_("This tab has running processes inside."),
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
            this.drag_motion.disconnect(this.motion);
            this.drag_leave.disconnect(this.leave);
        }

        public void
        change_title(string new_title)
        {
            this.title.label = new_title;
            this.title.ellipsize = Pango.EllipsizeMode.START;
        }

        public bool
        motion(Gtk.Widget      widget,
               Gdk.DragContext context,
               int             x,
               int             y,
               uint            t)
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove(this.timeout_id);
            }
            this.timeout_id = GLib.Timeout.add(500, () => {
                this.main_container.set_current_page(this.main_container.page_num(this.top_container));
                this.timeout_id = 0;
                return false;
            });
            return true;
        }

        public void
        leave(Gtk.Widget      widget,
              Gdk.DragContext context,
              uint            t)
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove(this.timeout_id);
                this.timeout_id = 0;
            }
        }
    }
}
