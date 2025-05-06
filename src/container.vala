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
using GLib;

namespace Terminus {
    /**
     * This is the terminal container. It can contain one terminal, or a Paned with
     * two containers. It can be splited in two elements and reagruped in a single
     * one.
     */

    public interface Killable : Object {
        public abstract void
        kill_all_children();
        public abstract void
        close();
    }

    public class Container : Gtk.Box {
        public Terminus.Container ?container1;
        public Terminus.Container ?container2;
        public weak Terminus.Notetab ?notetab;

        private Terminus.Terminal ?terminal;
        private Terminus.PanedPercentage ?paned;
        private weak Terminus.Container top_container;
        private weak Terminus.Container upper_container;
        private weak Terminus.Base main_container;
        private bool splited_horizontal;
        private string working_directory;
        private uint timeout_focus = 0;

        private weak Terminus.Terminal ?last_focus = null;
        private bool setting_focus = false;

        public signal void
        ended(Terminus.Container who);
        public signal void
        close_tab(Terminus.Container who);

        public Container(Terminus.Base       main_container,
                         string              working_directory,
                         string[] ?          commands,
                         Terminus.Terminal ? terminal,
                         Terminus.Container ?top_container,
                         Terminus.Container ?upper_container)
        {
            this.working_directory = working_directory;
            this.main_container = main_container;
            this.upper_container = upper_container;
            this.notetab = null;
            if (top_container == null) {
                this.top_container = this;
            } else {
                this.top_container = top_container;
            }

            if (terminal == null) {
                this.terminal = new Terminus.Terminal(this.main_container,
                                                      working_directory,
                                                      commands,
                                                      this.top_container,
                                                      this);
            } else {
                this.terminal = terminal;
                this.terminal.set_containers(this, this.top_container, this.main_container);
            }
            this.set_terminal_child();
            this.container1 = null;
            this.container2 = null;
        }

        public void
        update_focus()
        {
            if (this.last_focus != null) {
                this.setting_focus = true;
                this.timeout_focus = GLib.Timeout.add_once(350, () => {
                    this.timeout_focus = 0;
                    if (this.last_focus != null) {
                        this.last_focus.do_grab_focus();
                    }
                    this.setting_focus = false;
                });
            }
        }

        public void
        set_last_focus(Terminus.Terminal terminal)
        {
            if (this.setting_focus == false) {
                this.last_focus = terminal;
            }
        }

        private void
        remove_timeout()
        {
            if (this.timeout_focus != 0) {
                GLib.Source.remove(this.timeout_focus);
                this.timeout_focus = 0;
            }
        }

        public void
        terminal_ended(Terminus.Terminal terminal)
        {
            if (this.last_focus == terminal) {
                this.last_focus = null;
                this.remove_timeout();
            }
        }

        public void
        set_copy_enabled(bool enabled)
        {
            this.main_container.set_copy_enabled(enabled);
        }

        public Terminal ?
        extract_current_terminal()
        {
            if (this.terminal == null) {
                return null;
            }
            Terminal retval = this.terminal;
            this.remove(this.terminal);
            this.terminal.split_terminal.disconnect(this.split_terminal_cb);
            this.terminal.ended.disconnect(this.ended_cb);
            this.remove_timeout();
            return retval;
        }

        public void
        ask_kill_childs(string   title,
                        string   subtitle,
                        string   button_text,
                        Killable obj)
        {
            this.remove_timeout();
            this.main_container.ask_kill_childs.begin(title, subtitle, button_text, obj);
        }

        public bool
        check_if_running_processes()
        {
            if (this.terminal != null) {
                return this.terminal.has_child_running();
            } else {
                return this.container1.check_if_running_processes() | this.container2.check_if_running_processes();
            }
        }

        public void
        ask_close_tab()
        {
            this.remove_timeout();
            this.close_tab(this);
        }

        public void
        set_tab_title(string title)
        {
            if (this.notetab != null) {
                this.notetab.change_title(title);
            }
        }

        public void
        set_terminal_child()
        {
            this.remove_timeout();
            this.append(this.terminal);
            this.terminal.ended.connect(this.ended_cb);

            this.terminal.split_terminal.connect(this.split_terminal_cb);
            this.terminal.set_containers(this, this.top_container, this.main_container);

            this.paned = null;
            this.container1 = null;
            this.container2 = null;
        }

        public Gtk.Widget ?get_current_child()
        {
            if (this.terminal != null) {
                this.terminal.split_terminal.disconnect(this.split_terminal_cb);
                this.terminal.ended.disconnect(this.ended_cb);
                this.remove(this.terminal);
                return this.terminal;
            } else {
                this.container1.ended.disconnect(this.ended_child);
                this.container2.ended.disconnect(this.ended_child);
                this.remove(this.paned);
                return this.paned;
            }
        }

        public void
        ended_cb()
        {
            this.remove_timeout();
            this.ended(this);
        }

        public void
        split_terminal_cb(SplitAt   where,
                          Terminal ?new_terminal,
                          string ?  path)
        {
            this.remove_timeout();
            if ((where == SplitAt.TOP) || (where == SplitAt.BOTTOM)) {
                this.splited_horizontal = true;
            } else {
                this.splited_horizontal = false;
            }
            bool current_to_first;
            if ((where == SplitAt.BOTTOM) || (where == SplitAt.RIGHT)) {
                current_to_first = true;
            } else {
                current_to_first = false;
            }
            this.remove(this.terminal);
            this.terminal.split_terminal.disconnect(this.split_terminal_cb);
            this.terminal.ended.disconnect(this.ended_cb);

            this.paned = new Terminus.PanedPercentage(
                this.splited_horizontal ? Gtk.Orientation.VERTICAL : Gtk.Orientation.HORIZONTAL, 0.5);
            this.paned.hexpand = true;
            this.paned.vexpand = true;

            this.container1 = new Terminus.Container(this.main_container,
                                                     path != null ? path : this.working_directory,
                                                     null,
                                                     current_to_first ? this.terminal : new_terminal,
                                                     this.top_container,
                                                     this);
            this.container2 = new Terminus.Container(this.main_container,
                                                     path != null ? path : this.working_directory,
                                                     null,
                                                     current_to_first ? new_terminal : this.terminal,
                                                     this.top_container,
                                                     this);
            this.terminal.set_container(current_to_first ? this.container1 : this.container2);
            if (new_terminal != null) {
                new_terminal.set_containers(current_to_first ? this.container2 : this.container1, this.top_container,
                                            this.main_container);
            }
            this.container1.ended.connect(this.ended_child);
            this.container2.ended.connect(this.ended_child);
            this.paned.start_child = this.container1;
            this.paned.end_child = this.container2;
            this.append(this.paned);
            this.paned.set_visible(true);
            this.terminal = null;
        }

        public void
        move_terminal_focus(MoveFocus           direction,
                            Terminus.Container ?sender,
                            bool                searching_up)
        {
            this.remove_timeout();
            if (sender == null) {
                sender = this.container1;
            }
            if (this.terminal != null) {
                if (searching_up) {
                    if (this.upper_container != null) {
                        this.upper_container.move_terminal_focus(direction, this, true);
                    }
                } else {
                    this.terminal.do_grab_focus();
                }
                return;
            }
            switch (direction) {
            case Terminus.MoveFocus.UP:
            case Terminus.MoveFocus.DOWN:
                if (searching_up) {
                    if (this.splited_horizontal) {
                        if ((direction == Terminus.MoveFocus.UP) && (sender == this.container2)) {
                            this.container1.move_terminal_focus(direction, this, false);
                        } else if ((direction == Terminus.MoveFocus.DOWN) && (sender == this.container1)) {
                            this.container2.move_terminal_focus(direction, this, false);
                        } else {
                            if (this.upper_container != null) {
                                this.upper_container.move_terminal_focus(direction, this, true);
                            }
                        }
                    } else {
                        if (this.upper_container != null) {
                            this.upper_container.move_terminal_focus(direction, this, true);
                        }
                    }
                } else {
                    if (direction == Terminus.MoveFocus.UP) {
                        this.container2.move_terminal_focus(direction, this, false);
                    } else {
                        this.container1.move_terminal_focus(direction, this, false);
                    }
                }
                break;

            case Terminus.MoveFocus.LEFT:
            case Terminus.MoveFocus.RIGHT:
                if (searching_up) {
                    if (!this.splited_horizontal) {
                        if ((direction == Terminus.MoveFocus.LEFT) && (sender == this.container2)) {
                            this.container1.move_terminal_focus(direction, this, false);
                        } else if ((direction == Terminus.MoveFocus.RIGHT) && (sender == this.container1)) {
                            this.container2.move_terminal_focus(direction, this, false);
                        } else {
                            if (this.upper_container != null) {
                                this.upper_container.move_terminal_focus(direction, this, true);
                            }
                        }
                    } else {
                        if (this.upper_container != null) {
                            this.upper_container.move_terminal_focus(direction, this, true);
                        }
                    }
                } else {
                    if (direction == Terminus.MoveFocus.LEFT) {
                        this.container2.move_terminal_focus(direction, this, false);
                    } else {
                        this.container1.move_terminal_focus(direction, this, false);
                    }
                }
                break;
            }
        }

        public void
        do_grab_focus()
        {
            if (this.terminal == null) {
                this.container1.do_grab_focus();
            } else {
                this.terminal.do_grab_focus();
            }
        }

        public void
        ended_child(Terminus.Container child)
        {
            Terminus.Container old_container;

            this.remove_timeout();
            if (child == this.container1) {
                old_container = this.container2;
            } else {
                old_container = this.container1;
            }
            var new_child = old_container.get_current_child();
            if (this.container1 != null) {
                this.paned.start_child = null; //remove(this.container1);
                this.container1.ended.disconnect(this.ended_child);
                this.container1 = null;
            }
            if (this.container2 != null) {
                this.paned.end_child = null; //remove(this.container2);
                this.container2.ended.disconnect(this.ended_child);
                this.container2 = null;
            }
            if (this.paned != null) {
                this.remove(this.paned);
                this.paned = null;
            }
            if (new_child is Terminus.Terminal) {
                this.terminal = new_child as Terminus.Terminal;
                this.set_terminal_child();
                this.terminal.do_grab_focus();
            } else {
                this.paned = new_child as Terminus.PanedPercentage;
                this.container1 = old_container.container1;
                this.container2 = old_container.container2;
                this.container1.ended.connect(this.ended_child);
                this.container2.ended.connect(this.ended_child);
                this.append(this.paned);
                this.paned.set_visible(true);
                this.container1.do_grab_focus();
            }
        }

        public Terminus.Terminal ?
        find_terminal_by_pid(int pid)
        {
            if (this.terminal != null) {
                return this.terminal.find_terminal_by_pid(pid);
            }
            var terminal = this.container1.find_terminal_by_pid(pid);
            if (terminal == null) {
                terminal = this.container2.find_terminal_by_pid(pid);
            }
            return terminal;
        }
    }
}
