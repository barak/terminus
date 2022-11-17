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

    class Base : Gtk.Notebook {
        public signal void ended();
        public signal void new_window();
        public Gtk.Window ?top_window;
        private Gtk.Dialog notification_window;

        public Base(string      working_directory,
                    string[]   ?commands,
                    Gtk.Window ?top_window)
        {
            this.page_added.connect(this.check_pages);
            this.page_removed.connect(this.check_pages);
            this.new_terminal_tab(working_directory, commands);
            this.scrollable = true;
            this.top_window = top_window;
        }

        public void
        ask_kill_childs(string title, Killable obj)
        {
            this.notification_window = new Gtk.Dialog.with_buttons("", this.top_window, Gtk.DialogFlags.MODAL,
                                                                   _("Cancel"), Gtk.ResponseType.REJECT,
                                                                   _("Close the terminal"), Gtk.ResponseType.ACCEPT,
                                                                   null);
            this.notification_window.transient_for = this.top_window;
            var container = this.notification_window.get_content_area();
            var title_label = new Gtk.Label("<b>"+title+"</b>");
            title_label.use_markup = true;
            var subtext_label = new Gtk.Label(_("Closing this tile will kill it."));
            container.pack_start(title_label, true, true, 10);
            container.pack_start(subtext_label, true, true, 10);
            this.notification_window.get_widget_for_response(Gtk.ResponseType.ACCEPT).get_style_context().add_class("destructive-action");
            this.notification_window.decorated = false;
            this.notification_window.child = container;
            this.notification_window.response.connect((response_id) => {
                this.notification_window.hide();
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    obj.kill_all_children();
                }
            });
            this.notification_window.show_all();
        }

        public void
        new_terminal_tab(string    working_directory,
                         string[] ?commands)
        {
            var term = new Terminus.Container(this, working_directory, commands, null, null, null);
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
        check_pages(Gtk.Widget child,
                    uint       page_num)
        {
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
