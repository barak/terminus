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

    public class Base {
        public signal void
        ended();
        public signal void
        new_window();

        public weak Terminus.Window ?top_window;
        public weak TerminusRoot terminus_root;
        private Gtk.Notebook notebook;

        public Base(TerminusRoot       root,
                    string             working_directory,
                    string[] ?         commands,
                    Terminus.Window ?  top_window,
                    Terminus.Terminal ?terminal = null)
        {
            this.notebook = new Gtk.Notebook();
            this.terminus_root = root;
            this.notebook.page_added.connect(this.check_pages);
            this.notebook.page_removed.connect(this.check_pages);
            this.new_terminal_tab(working_directory, commands, terminal);
            this.notebook.scrollable = true;
            this.top_window = top_window;
            this.notebook.switch_page.connect((notebook, page_widget, page_num) => {
                var container = page_widget as Terminus.Container;
                container.update_focus();
            });
        }

        public void
        insert_notebook_into(Gtk.Window window)
        {
            window.set_child(this.notebook);
            this.notebook.set_visible(true);
        }

        public void
        set_copy_enabled(bool enabled)
        {
            this.terminus_root.set_copy_enabled(enabled);
        }

        public void
        drop_terminal(Terminal terminal)
        {
            this.new_terminal_tab("", null, terminal);
        }

        public bool
        accepts_drop(Terminal terminal)
        {
            return true;
        }

        public async void
        ask_kill_childs(string   title,
                        string   subtitle,
                        string   button_text,
                        Killable obj)
        {
            var notification_window = new Gtk.AlertDialog(title);
            notification_window.detail = subtitle;
            notification_window.buttons = {
                _("Cancel"), button_text
            };
            notification_window.cancel_button = 0;
            notification_window.default_button = 1;
            var result = yield notification_window.
                         choose(this.top_window,
                                null);

            if (result == 1) {
                obj.kill_all_children();
                obj.close();
            }
        }

        public bool
        check_if_running_processes()
        {
            for (var i = 0; i < this.notebook.get_n_pages(); i++) {
                var page = (Terminus.Container) this.notebook.get_nth_page(i);
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
            var container = new Terminus.Container(this, working_directory, commands, terminal, null, null);
            var notetab = new Terminus.Notetab(this, container);
            container.notetab = notetab;
            container.ended.connect((w) => {
                this.delete_page(container);
            });
            container.set_visible(true);
            var page = this.notebook.append_page(container, notetab);
            this.notebook.set_current_page(page);
            this.notebook.set_tab_reorderable(container, true);
        }

        public void
        new_terminal_window()
        {
            this.new_window();
        }

        public void
        focus_page_containing(Terminus.Container element)
        {
            this.notebook.set_current_page(this.notebook.page_num(element));
        }

        public void
        delete_page(Terminus.Container top_container)
        {
            var page = this.notebook.page_num(top_container);
            if (page != -1) {
                this.notebook.remove_page(page);
            }
        }

        public void
        check_pages(Gtk.Widget ?child,
                    uint        page_num)
        {
            var npages = this.notebook.get_n_pages();
            if (npages == 0) {
                this.ended();
            }
            if ((npages <= 1)) {
                this.notebook.show_tabs = false;
            } else {
                this.notebook.show_tabs = true;
            }
        }

        public void
        next_tab()
        {
            var p = this.notebook.get_n_pages();
            if (this.notebook.page + 1 == p) {
                this.notebook.set_current_page(0);
            } else {
                this.notebook.next_page();
            }
        }

        public void
        prev_tab()
        {
            if (this.notebook.page == 0) {
                var p = this.notebook.get_n_pages();
                this.notebook.set_current_page(p - 1);
            } else {
                this.notebook.prev_page();
            }
        }

        public void
        show()
        {
            this.notebook.set_visible(true);
        }

        public Terminus.Terminal ?
        find_terminal_by_pid(int pid)
        {
            for (int i = 0; i < this.notebook.get_n_pages(); i++) {
                var container = this.notebook.get_nth_page(i) as Terminus.Container;
                var terminal = container.find_terminal_by_pid(pid);
                if (terminal != null) {
                    return terminal;
                }
            }
            return null;
        }
    }
}
