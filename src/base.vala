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

namespace Terminus {
    /**
     * This is the main class, that contains everything. This class must be
     * enclosed in a window.
     */

    public class Base : Gtk.Notebook, DnDDestination {
        public signal void
        ended();
        public signal void
        new_window();

        public Gtk.Window ?top_window;
        private Gtk.MessageDialog notification_window;
        private ulong dnd_status_id;

        public Base(string             working_directory,
                    string[]   ?       commands,
                    Gtk.Window ?       top_window,
                    Terminus.Terminal ?terminal = null)
        {
            this.page_added.connect(this.check_pages);
            this.page_removed.connect(this.check_pages);
            this.new_terminal_tab(working_directory, commands, terminal);
            this.scrollable = true;
            this.top_window = top_window;
            this.dnd_status_id = Terminus.dnd_manager.dnd_status.connect(() => {
                this.check_pages(null, 0);
            });
            Gtk.drag_dest_set(this, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, null,
                              Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.DEFAULT);
            Gtk.drag_dest_set_target_list(this, dnd_manager.targets);
            this.drag_drop.connect((widget, context, x, y, time) => {
                Terminus.dnd_manager.set_destination(this);
                return true;
            });
        }

        public void drop_terminal(Terminal terminal) {
            this.new_terminal_tab("", null, terminal);
        }

        public bool accepts_drop(Terminal terminal) {
            return true;
        }

        public void
        ask_kill_childs(string   title,
                        string   subtitle,
                        string   button_text,
                        Killable obj)
        {
            this.notification_window = new Gtk.MessageDialog(this.top_window,
                                                             Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                                                             Gtk.MessageType.QUESTION,
                                                             Gtk.ButtonsType.NONE,
                                                             "<b>" + title + "</b>");
            this.notification_window.format_secondary_markup(subtitle);
            this.notification_window.use_markup = true;
            this.notification_window.add_button(_("Cancel"), Gtk.ResponseType.REJECT);
            var close_button = this.notification_window.add_button(button_text, Gtk.ResponseType.ACCEPT);
            close_button.get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            this.notification_window.set_default_response(Gtk.ResponseType.REJECT);
            this.notification_window.response.connect((response_id) => {
                this.notification_window.hide();
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    obj.kill_all_children();
                }
            });
            this.notification_window.show_all();
        }

        public bool
        check_if_running_processes()
        {
            for (var i = 0; i < this.get_n_pages(); i++) {
                var page = (Terminus.Container) this.get_nth_page(i);
                if (page.check_if_running_processes()) {
                    return true;
                }
            }
            return false;
        }

        public void
        new_terminal_tab(string    working_directory,
                         string[] ?commands,
                         Terminal ?terminal = null)
        {
            var term = new Terminus.Container(this, working_directory, commands, terminal, null, null);
            term.ended.connect((w) => {
                this.delete_page(term);
            });
            term.show_all();
            var page = this.append_page(term, term.notetab);
            this.set_current_page(page);
        }

        public void
        new_terminal_window()
        {
            this.new_window();
        }

        public void
        delete_page(Terminus.Container top_container)
        {
            var page = this.page_num(top_container);
            if (page != -1) {
                this.remove_page(page);
            }
        }

        public void
        check_pages(Gtk.Widget?child,
                    uint       page_num)
        {
            var npages = this.get_n_pages();
            if (npages == 0) {
                Terminus.dnd_manager.disconnect(this.dnd_status_id);
                this.ended();
            }
            if ((npages <= 1) && (!Terminus.dnd_manager.doing_dnd)) {
                this.show_tabs = false;
            } else {
                this.show_tabs = true;
            }
        }

        public void
        next_tab()
        {
            var p = this.get_n_pages();
            if (this.page + 1 == p) {
                this.set_current_page(0);
            } else {
                this.next_page();
            }
        }

        public void
        prev_tab()
        {
            if (this.page == 0) {
                var p = this.get_n_pages();
                this.set_current_page(p - 1);
            } else {
                this.prev_page();
            }
        }
    }
}
