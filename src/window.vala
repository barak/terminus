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

using Gtk;

namespace Terminus {
    public class Window : Gtk.ApplicationWindow, Killable, DnDDestination {
        public signal void
        ended(Terminus.Window window);
        public signal void
        new_window();

        private Gtk.HeaderBar headerBar;
        private bool is_guake;
        private bool ask_close;
        private Terminus.Base terminal_base;

        public void
        kill_all_children()
        {
            this.ask_close = false;
        }

        public Window(Terminus.TerminusRoot application,
                      bool                  guake_mode,
                      string ?              working_directory,
                      string[]              commands,
                      Terminus.Base ?       terminal_base = null,
                      Terminus.Terminal ?   inner_terminal = null)
        {
            this.ask_close = true;
            this.headerBar = new Gtk.HeaderBar();
            this.set_titlebar(this.headerBar);
            this.headerBar.show_title_buttons = true;
            this.headerBar.set_title_widget(new Gtk.Label("Terminus"));
            this.headerBar.set_visible(true);

            this.is_guake = guake_mode;

            this.close_request.connect(() => {
                if (this.ask_close && this.terminal_base.check_if_running_processes()) {
                    this.terminal_base.ask_kill_childs.begin(_("This window has running processes inside."),
                                                             _("Closing it will kill them."),
                                                             _("Close window"),
                                                             this);
                    return true;
                } else {
                    this.ended(this);
                    return false;
                }
            });

            if (terminal_base == null) {
                this.terminal_base = new Terminus.Base(application, working_directory, commands, this, inner_terminal);
            } else {
                this.terminal_base = terminal_base;
                terminal_base.top_window = this;
            }
            this.terminal_base.ended.connect(this.ended_cb);

            this.terminal_base.new_window.connect(() => {
                this.new_window();
            });

            this.show.connect_after(() => {
                GLib.Timeout.add_once(500,
                                      () => {
                    this.present();
                });
            });

            if (guake_mode) {
                this.headerBar.set_visible(false);
                this.title = "TerminusGuake";

                if (Terminus.settings.get_int("guake-height") <= 300) {
                    Terminus.settings.set_int("guake-height", 300);
                }
                this.map.connect_after(() => {
                    this.unmaximize();
                    var surface = this.get_surface();
                    var monitor = surface.get_display().get_monitor_at_surface(surface);
                    var geometry = monitor.geometry;
                    var scale = monitor.scale;
                    var width = (int) (geometry.width / scale);
                    var desired_height = Terminus.settings.get_int("guake-height");
                    this.set_size_request(width, desired_height);
                });
                this.notify.connect((sender, property) => {
                    if (property.name == "default-height") {
                        var size = this.get_size(Gtk.Orientation.VERTICAL);
                        if (size != Terminus.settings.get_int("guake-height")) {
                            Terminus.settings.set_int("guake-height", size);
                        }
                    }
                });

                this.terminal_base.insert_notebook_into(this);
            } else {
                this.terminal_base.insert_notebook_into(this);
                this.terminal_base.show();
                this.present();
            }
            this.application = application;

            var new_window_button = new Gtk.Button.from_icon_name("window-new-symbolic");
            this.headerBar.pack_start(new_window_button);
            new_window_button.set_visible(true);
            var new_tab_button = new Gtk.Button.from_icon_name("tab-new-symbolic");
            this.headerBar.pack_start(new_tab_button);
            new_tab_button.set_visible(true);
            new_tab_button.clicked.connect(() => {
                this.terminal_base.new_terminal_tab("", null);
            });
            new_window_button.clicked.connect(() => {
                this.terminal_base.new_terminal_window();
            });
            var drop_target_terminal = new Gtk.DropTarget(typeof(Terminus.Terminal),
                                                          Gdk.DragAction.COPY | Gdk.DragAction.MOVE |
                                                          Gdk.DragAction.LINK);
            var thiswidget = this as Gtk.Widget;
            thiswidget.add_controller(drop_target_terminal); // there is a bug in Vala, and this fails when doing directly over 'this'
            drop_target_terminal.drop.connect((target, drag_value, x, y) => {
                Terminus.Terminal terminal = drag_value as Terminus.Terminal;
                terminal.drop_terminal_into(this);
                return true;
            });
        }

        public void
        destroy_window()
        {
            this.ended(this);
            this.destroy();
        }

        public void
        drop_terminal(Terminal terminal)
        {
            this.terminal_base.new_terminal_tab("", null, terminal);
        }

        public bool
        accepts_drop(Terminal terminal)
        {
            return true;
        }

        public void
        ended_cb()
        {
            this.terminal_base.ended.disconnect(this.ended_cb);
            this.destroy_window();
        }

        public Terminus.Terminal ?
        find_terminal_by_pid(int pid)
        {
            return this.terminal_base.find_terminal_by_pid(pid);
        }
    }
}
