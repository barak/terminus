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
    class Fixed : Gtk.Fixed {
        public override void
        get_preferred_width(out int minimum_width,
                            out int natural_width)
        {
            base.get_preferred_width(out minimum_width, out natural_width);
            minimum_width = 1;
            natural_width = 1;
        }

        public override void
        get_preferred_height(out int minimum_height,
                             out int natural_height)
        {
            base.get_preferred_height(out minimum_height, out natural_height);
            minimum_height = 1;
            natural_height = 1;
        }
    }

    class Window : Gtk.ApplicationWindow, Killable {
        public signal void
        ended(Terminus.Window window);
        public signal void
        new_window();

        private Gtk.HeaderBar headerBar;
        private int current_size;
        private int mouseY;
        private Gtk.Paned paned;
        private Terminus.Fixed fixed;
        private bool is_guake;
        private Gtk.Button new_tab_button;
        private Gtk.Button new_window_button;

        private Terminus.Base terminal_base;
        private int initialized;

        private Gdk.Rectangle
        get_monitor_workarea()
        {
            var display = Gdk.Display.get_default();
            var monitor = display.get_primary_monitor();
            var workarea = monitor.get_workarea();
            return workarea;
        }

        public void
        kill_all_children()
        {
            this.destroy();
        }

        public Window(Gtk.Application  application,
                      bool             guake_mode,
                      string          ?working_directory,
                      string[]         commands,
                      Terminus.Base   ?terminal_base = null,
                      string          ?window_title = null,
                      Terminus.Terminal ?inner_terminal = null)
        {
            this.headerBar = new Gtk.HeaderBar();
            this.set_titlebar(this.headerBar);
            this.headerBar.has_subtitle = false;
            this.headerBar.show_close_button = true;
            this.headerBar.title = "Terminus";
            this.headerBar.show();

            this.is_guake = guake_mode;
            this.initialized = 0;

            this.type_hint = Gdk.WindowTypeHint.NORMAL;
            this.focus_on_map = true;

            this.delete_event.connect(() => {
                if (this.terminal_base.check_if_running_processes()) {
                    this.terminal_base.ask_kill_childs(_("This window has running processes inside."),
                                                  _("Closing it will kill them."),
                                                  _("Close window"),
                                                  this);
                    return true;
                } else {
                    return false;
                }
            });

            this.destroy.connect((w) => {
                this.ended(this);
            });

            if (terminal_base == null) {
                this.terminal_base = new Terminus.Base(working_directory, commands, this, inner_terminal);
            } else {
                this.terminal_base = terminal_base;
                terminal_base.top_window = this;
            }
            this.terminal_base.ended.connect(this.ended_cb);

            this.terminal_base.new_window.connect(() => {
                this.new_window();
            });

            this.show.connect_after(() => {
                GLib.Timeout.add(500,
                                 () => {
                    this.present();
                    return false;
                });
            });

            if (guake_mode) {
                if (window_title != null) {
                    this.title = window_title;
                }
                this.set_properties();

                this.current_size = Terminus.settings.get_int("guake-height");
                if (this.current_size <= 0) {
                    this.current_size = 300;
                    Terminus.settings.set_int("guake-height", this.current_size);
                }
                this.map.connect_after(this.mapped);
                this.realize.connect_after(() => {
                    this.set_size();
                });
                this.paned = new Gtk.Paned(Gtk.Orientation.VERTICAL);
                this.paned.wide_handle = true;
                this.paned.events = Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK |
                                    Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK;
                this.add(this.paned);
                this.paned.add1(this.terminal_base);
                this.fixed = new Terminus.Fixed();
                this.paned.add2(fixed);
                this.mouseY = -1;

                this.paned.motion_notify_event.connect((widget, event) => {
                    if (this.mouseY < 0) {
                        return false;
                    }

                    if ((event.state & Gdk.ModifierType.BUTTON1_MASK) == 0) {
                        this.mouseY = -1;
                        Terminus.settings.set_int("guake-height", this.current_size);
                        return false;
                    }

                    int y;
                    y = (int) (event.y_root);
                    int newval = y - this.mouseY;
                    this.current_size += newval;
                    this.mouseY = y;
                    if (check_wayland() == 0) {
                        this.resize(this.get_monitor_workarea().width, this.current_size);
                        this.set_size_request(this.get_monitor_workarea().width, this.current_size);
                    } else {
                        int width, height;
                        this.get_size(out width, out height);
                        this.resize(width, this.current_size);
                        this.set_size_request(width, this.current_size);
                    }
                    this.paned.set_position(this.current_size);
                    Terminus.settings.set_int("guake-height", this.current_size);
                    return true;
                });

                this.paned.button_press_event.connect((widget, event) => {
                    if (event.button != 1) {
                        return false;
                    }
                    int y;
                    y = (int) (event.y_root);
                    this.mouseY = y;
                    return true;
                });

                this.paned.button_release_event.connect((widget, event) => {
                    if (event.button != 1) {
                        return false;
                    }
                    this.mouseY = -1;
                    return true;
                });

                this.paned.show_all();
            } else {
                this.add(this.terminal_base);
                this.terminal_base.show_all();
                this.present();
            }
            this.application = application;

            this.new_tab_button = new Gtk.Button();
            this.new_tab_button.add(new Gtk.Image.from_resource("/com/rastersoft/terminus/pixmaps/new_tab.svg"));
            this.headerBar.pack_start(this.new_tab_button);
            this.new_tab_button.show_all();
            this.new_window_button = new Gtk.Button.from_icon_name("window-new-symbolic", Gtk.IconSize.BUTTON);
            this.headerBar.pack_start(this.new_window_button);
            this.new_window_button.show_all();
            this.new_tab_button.clicked.connect(() => {
                this.terminal_base.new_terminal_tab("", null);
            });
            this.new_window_button.clicked.connect(() => {
                this.terminal_base.new_terminal_window();
            });

        }

        public void
        ended_cb()
        {
            this.terminal_base.ended.disconnect(this.ended_cb);
            this.destroy();
        }

        public void
        mapped()
        {
            this.set_properties();
            this.set_size();
        }

        private void
        set_properties()
        {
            if (check_wayland() == 0) {
                this.stick();
                this.set_keep_above(true);
                this.set_skip_taskbar_hint(true);
                this.set_skip_pager_hint(true);
            }
            this.set_decorated(false);
        }

        private void
        set_size()
        {
            if (check_wayland() == 0) {
                var workarea = this.get_monitor_workarea();
                this.move(workarea.x, workarea.y);
                this.paned.set_position(this.current_size);
                this.resize(workarea.width, this.current_size);
                this.set_size_request(workarea.width, this.current_size);
            } else {
                int width, height;
                this.get_size(out width, out height);
                this.resize(width, this.current_size);
                this.set_size_request(width, this.current_size);
                this.unmaximize();
                this.paned.set_position(this.current_size);
            }
        }
    }
}
