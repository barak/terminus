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

using Pango;

namespace Terminus {
    /**
     * This is the widget put in each tab
     */

    public class Notetab : Gtk.Box, Killable, DnDDestination {
        private weak Terminus.Container top_container;
        private Gtk.Label title;
        private weak Terminus.Base main_container;
        private Gtk.Box inner_box;
        private uint timeout_id;
        private string current_title;

        public Notetab(Terminus.Base      main_container,
                       Terminus.Container top_container)
        {
            this.current_title = "";
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
            this.inner_box.append(this.title);
            this.inner_box.append(close_button);
            this.append(this.inner_box);
            this.set_visible(true);
            close_button.clicked.connect(() => {
                this.close_tab();
            });
            var click_controller = new Gtk.GestureClick();
            click_controller.button = 2;
            this.add_controller(click_controller);
            click_controller.released.connect((controller, n_press, x, y) => {
                if (n_press == 1) {
                    this.close_tab();
                }
            });
            var drop_target_terminal = new Gtk.DropTarget(typeof(Terminus.Terminal),
                                                          Gdk.DragAction.COPY | Gdk.DragAction.MOVE |
                                                          Gdk.DragAction.LINK);
            this.add_controller(drop_target_terminal);
            drop_target_terminal.drop.connect((target, drag_value, x, y) => {
                Terminus.Terminal terminal = drag_value as Terminus.Terminal;
                terminal.drop_terminal_into(this);
                return true;
            });
            drop_target_terminal.motion.connect((target, x, y) => {
                if (this.timeout_id != 0) {
                    GLib.Source.remove(this.timeout_id);
                }
                this.timeout_id = GLib.Timeout.add_once(500, () => {
                    this.main_container.focus_page_containing(this.top_container);
                    this.timeout_id = 0;
                });
                return Gdk.DragAction.MOVE;
            });
            drop_target_terminal.leave.connect((target) => {
                if (this.timeout_id != 0) {
                    GLib.Source.remove(this.timeout_id);
                    this.timeout_id = 0;
                }
            });
            Terminus.settings.changed.connect((name) => {
                if (name == "max-tab-text-len") {
                    this.update_title();
                }
            });
        }

        public void
        close()
        {
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
                this.main_container.ask_kill_childs.begin(_("This tab has running processes inside."),
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
            this.current_title = new_title;
            this.update_title();
        }

        private void
        update_title()
        {
            var max_title_len = Terminus.settings.get_int("max-tab-text-len");
            if (this.current_title.length > max_title_len) {
                this.title.label = "..." + this.current_title.substring(this.current_title.length - max_title_len);
            } else {
                this.title.label = this.current_title;
            }
        }
    }
}
