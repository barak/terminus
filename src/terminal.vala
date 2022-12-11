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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Vte;
using Gtk;
using Gdk;
using GLib;
using Posix;

namespace Terminus {
    /**
     * This is the terminal itself, available in each container.
     */

    public class Terminal : Gtk.Box, Killable, DnDDestination {
        private int pid;
        private Vte.Terminal vte_terminal;
        private Gtk.Label title;
        private Gtk.EventBox titlebox;
        private Gtk.EventBox closeButton;
        private Gtk.MenuItem item_copy;
        private Gtk.Menu menu_container;
        private Terminus.Container top_container;
        private Terminus.Container container;
        private Terminus.Base main_container;
        private Gtk.Scrollbar right_scroll;
        private double title_r;
        private double title_g;
        private double title_b;
        private double fg_r;
        private double fg_g;
        private double fg_b;
        private SplitAt split_mode;
        private bool doing_dnd;
        private bool had_focus;

        public signal void
        ended(Terminus.Terminal terminal);
        public signal void
        split_terminal(SplitAt            where,
                       Terminus.Terminal ?new_terminal);

        public bool
        compare_terminal(Vte.Terminal ?terminal)
        {
            return this.vte_terminal == terminal;
        }

        public void
        extract_from_container()
        {
            this.container.extract_current_terminal();
            this.container.ended(this.container);
        }

        public bool
        accepts_drop(Terminal terminal)
        {
            return true;
        }

        public void
        drop_into(DnDDestination destination)
        {
            if (!destination.accepts_drop(this)) {
                return;
            }
            if (destination == this) {
                return;
            }
            var old_container = this.container;
            this.container.extract_current_terminal();
            destination.drop_terminal(this);
            old_container.ended_cb();
        }

        public void
        drop_terminal(Terminal terminal)
        {
            this.split_terminal(this.split_mode, terminal);
            this.split_mode = SplitAt.NONE;
        }

        private void
        add_separator(Gtk.Menu ?menu = null)
        {
            var separator = new Gtk.SeparatorMenuItem();
            if (menu == null) {
                this.menu_container.append(separator);
            } else {
                menu.append(separator);
            }
        }

        private Gtk.MenuItem
        new_menu_element(string    text,
                         string ?  icon = null,
                         Gtk.Menu ?menu = null)
        {
            Gtk.MenuItem item;
            if (icon == null) {
                item = new Gtk.MenuItem.with_label(text);
            } else {
                item = new Gtk.MenuItem();
                var tmpbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
                var tmplabel = new Gtk.Label(text);
                var tmpicon = new Gtk.Image.from_resource(icon);
                tmpbox.pack_start(tmpicon, false, true);
                tmpbox.pack_start(tmplabel, false, true);
                item.add(tmpbox);
            }
            if (menu == null) {
                this.menu_container.append(item);
            } else {
                menu.append(item);
            }
            return item;
        }

        private void
        create_menu()
        {
            this.menu_container = new Gtk.Menu();
            this.item_copy = this.new_menu_element(_("Copy"));
            this.item_copy.activate.connect(() => {
                this.do_copy();
            });

            var item = this.new_menu_element(_("Paste"));
            item.activate.connect(() => {
                this.do_paste();
            });

            this.add_separator();

            item = this.new_menu_element(_("Select all"));
            item.activate.connect(() => {
                this.vte_terminal.select_all();
            });

            this.add_separator();

            item = this.new_menu_element(_("Split horizontally"), "/com/rastersoft/terminus/pixmaps/horizontal.svg");
            item.activate.connect(() => {
                this.split_terminal(SplitAt.BOTTOM, null);
            });
            item = this.new_menu_element(_("Split vertically"), "/com/rastersoft/terminus/pixmaps/vertical.svg");
            item.activate.connect(() => {
                this.split_terminal(SplitAt.RIGHT, null);
            });

            this.add_separator();

            item = this.new_menu_element(_("New tab"));
            item.activate.connect(() => {
                this.main_container.new_terminal_tab("", null);
            });

            item = this.new_menu_element(_("New window"));
            item.activate.connect(() => {
                this.main_container.new_terminal_window();
            });

            this.add_separator();

            var submenu = new Gtk.Menu();
            item = this.new_menu_element(_("Extra"));
            item.submenu = submenu;

            item = this.new_menu_element(_("Reset terminal"), null, submenu);
            item.activate.connect(() => {
                this.vte_terminal.reset(true, false);
            });

            item = this.new_menu_element(_("Reset and clear terminal"), null, submenu);
            item.activate.connect(() => {
                this.vte_terminal.reset(true, true);
            });

            this.add_separator();

            item = this.new_menu_element(_("Preferences"));
            item.activate.connect(() => {
                Terminus.main_root.show_properties();
            });

            this.add_separator();

            item = this.new_menu_element(_("Close"));
            item.activate.connect(() => {
                this.kill_child();
            });
            this.menu_container.show_all();
        }

        public void
        do_grab_focus()
        {
            this.vte_terminal.grab_focus();
        }

        public void
        set_containers(Terminus.Container container,
                       Terminus.Container top_container,
                       Terminus.Base      main_container)
        {
            this.container = container;
            this.top_container = top_container;
            this.main_container = main_container;
        }

        public void
        set_container(Terminus.Container container)
        {
            this.container = container;
        }

        private void
        do_copy()
        {
            this.vte_terminal.copy_primary();
            var primary = Gtk.Clipboard.get(Gdk.SELECTION_PRIMARY);
            var clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD);
            clipboard.set_text(primary.wait_for_text(), -1);
        }

        private void
        do_paste()
        {
            var primary = Gtk.Clipboard.get(Gdk.SELECTION_PRIMARY);
            var clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD);
            primary.set_text(clipboard.wait_for_text(), -1);
            this.vte_terminal.paste_primary();
        }

        public Terminal(Terminus.Base       main_container,
                        string              working_directory,
                        string[]           ?commands,
                        Terminus.Container  top_container,
                        Terminus.Container  container)
        {
            this.container = container;
            // when creating a new terminal, it must take the focus
            had_focus = true;
            this.split_mode = SplitAt.NONE;
            this.doing_dnd = false;
            this.map.connect_after(() => {
                // this ensures that the title is updated when the window is shown
                GLib.Timeout.add(500, update_title_cb);
            });

            this.main_container = main_container;
            this.top_container = top_container;
            this.orientation = Gtk.Orientation.VERTICAL;

            this.title = new Gtk.Label("");
            this.titlebox = new Gtk.EventBox();
            this.title.draw.connect((cr) => {
                cr.set_source_rgb(this.title_r, this.title_g, this.title_b);
                cr.paint();
                return false;
            });
            // a titlebox to have access to the background color
            this.titlebox.add(this.title);

            this.closeButton = new Gtk.EventBox();
            var label = new Gtk.Image.from_icon_name("window-close-symbolic", Gtk.IconSize.BUTTON);
            this.closeButton.button_release_event.connect((event) => {
                this.kill_child();
                return false;
            });
            this.closeButton.add(label);
            var titleContainer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            titleContainer.pack_start(this.titlebox, true, true);
            titleContainer.pack_start(this.closeButton, false, true);

            var newbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.pack_start(titleContainer, false, true);
            this.pack_start(newbox, true, true);

            this.vte_terminal = new Vte.Terminal();


            this.vte_terminal.window_title_changed.connect_after(() => {
                this.update_title();
            });
            this.vte_terminal.focus_in_event.connect_after((event) => {
                this.update_title();
                this.had_focus = true;
                return false;
            });
            this.vte_terminal.focus_out_event.connect_after((event) => {
                this.update_title();
                this.had_focus = false;
                return false;
            });
            this.vte_terminal.resize_window.connect_after((x, y) => {
                this.update_title();
            });
            this.vte_terminal.map.connect_after((w) => {
                if (this.had_focus) {
                    GLib.Timeout.add(500,
                                     () => {
                        this.vte_terminal.grab_focus();
                        return false;
                    });
                }
            });

            Terminus.settings.bind("scroll-on-output",
                                   this.vte_terminal,
                                   "scroll_on_output",
                                   GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("scroll-on-keystroke",
                                   this.vte_terminal,
                                   "scroll_on_keystroke",
                                   GLib.SettingsBindFlags.DEFAULT);

            this.right_scroll = new Gtk.Scrollbar(Gtk.Orientation.VERTICAL, this.vte_terminal.vadjustment);

            newbox.pack_start(this.vte_terminal, true, true);
            newbox.pack_start(right_scroll, false, true);

            string[] cmd = {};
            if (Terminus.settings.get_boolean("use-custom-shell")) {
                cmd += Terminus.settings.get_string("shell-command");
            } else {
                bool found = false;
                unowned Posix.Passwd passwd;
                Posix.setpwent();
                while (null != (passwd = Posix.getpwent())) {
                    if (passwd.pw_name == GLib.Environment.get_user_name()) {
                        found = true;
                        cmd += passwd.pw_shell;
                        break;
                    }
                }
                if (!found) {
                    cmd += "/bin/sh";
                }
                Posix.endpwent();
            }
            if ((commands != null) && (commands.length != 0)) {
                cmd += "-c";
                foreach (var command in commands) {
                    cmd += command;
                }
            }
            var environment = GLib.Environ.set_variable(GLib.Environ.get(), "TERM", "xterm-256color", true);;
            this.vte_terminal.spawn_sync(Vte.PtyFlags.DEFAULT,
                                         working_directory,
                                         cmd,
                                         environment,
                                         0,
                                         null,
                                         out this.pid);
            this.vte_terminal.child_exited.connect(() => {
                this.ended(this);
            });

            this.create_menu();

            this.vte_terminal.button_press_event.connect(this.button_event);
            this.vte_terminal.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            this.vte_terminal.add_events(Gdk.EventMask.SCROLL_MASK);

            Terminus.settings.changed.connect(this.settings_changed);

            this.vte_terminal.key_press_event.connect(this.on_key_press);
            this.vte_terminal.scroll_event.connect(this.on_scroll);
            this.update_title();

            // Set all the properties
            settings_changed("infinite-scroll");
            settings_changed("use-system-font");
            settings_changed("color-palete");
            settings_changed("fg-color");
            settings_changed("bg-color");
            settings_changed("cursor-shape");
            settings_changed("terminal-bell");
            settings_changed("allow-bold");
            settings_changed("rewrap-on-resize");
            settings_changed("pointer-autohide");

            // set DnD
            Gtk.drag_source_set(this.titlebox,
                                Gdk.ModifierType.BUTTON1_MASK,
                                null,
                                Gdk.DragAction.MOVE | Gdk.DragAction.COPY);
            Gtk.drag_source_set_target_list(this.titlebox, dnd_manager.targets);
            this.titlebox.drag_end.connect((widget, context) => {
                Terminus.dnd_manager.do_drop();
            });
            this.titlebox.drag_begin.connect((widget, context) => {
                Terminus.dnd_manager.begin_dnd();
                Terminus.dnd_manager.set_origin(this);
            });
            Gtk.drag_dest_set(this.vte_terminal, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, null,
                              Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.DEFAULT);
            Gtk.drag_dest_set_target_list(this.vte_terminal, dnd_manager.targets);
            this.vte_terminal.drag_motion.connect((widget, context, x, y, time) => {
                if (Terminus.dnd_manager.is_origin(widget as Vte.Terminal)) {
                    this.doing_dnd = false;
                    return false;
                }
                this.doing_dnd = true;
                var nx = 2.0 * x / widget.get_allocated_width() - 1.0;
                var ny = 2.0 * y / widget.get_allocated_height() - 1.0;

                if (ny <= nx) {
                    if (ny <= (-nx)) {
                        this.split_mode = SplitAt.TOP;
                    } else {
                        this.split_mode = SplitAt.RIGHT;
                    }
                } else {
                    if (ny <= (-nx)) {
                        this.split_mode = SplitAt.LEFT;
                    } else {
                        this.split_mode = SplitAt.BOTTOM;
                    }
                }
                this.vte_terminal.queue_draw();
                return true;
            });
            this.vte_terminal.drag_leave.connect(() => {
                this.doing_dnd = false;
            });
            this.vte_terminal.drag_drop.connect((widget, context, x, y, time) => {
                Terminus.dnd_manager.set_destination(this);
                return true;
            });
            // To avoid creating a new window if dropping accidentally over a terminal title
            Gtk.drag_dest_set(titleContainer, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, null,
                              Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.DEFAULT);
            Gtk.drag_dest_set_target_list(titleContainer, dnd_manager.targets);
            titleContainer.drag_drop.connect((widget, context, x, y, time) => {
                Terminus.dnd_manager.set_destination(new VoidDnDDestination());
                return true;
            });
            this.vte_terminal.draw.connect_after((cr) => {
                if (!this.doing_dnd) {
                    return false;
                }
                cr.save();
                cr.scale(this.vte_terminal.get_allocated_width(), this.vte_terminal.get_allocated_height());
                switch (this.split_mode) {
                case SplitAt.TOP:
                    cr.rectangle(0, 0, 1, 0.5);
                    break;

                case SplitAt.BOTTOM:
                    cr.rectangle(0, 0.5, 1, 0.5);
                    break;

                case SplitAt.LEFT:
                    cr.rectangle(0, 0, 0.5, 1);
                    break;

                case SplitAt.RIGHT:
                    cr.rectangle(0.5, 0, 0.5, 1);
                    break;

                default:
                    break;
                }
                cr.set_source_rgba(this.fg_r, this.fg_g, this.fg_b, 0.5);
                cr.fill();
                cr.restore();
                return false;
            });
            this.show_all();
        }

        public bool
        has_child_running()
        {
            var      procdir = GLib.File.new_for_path("/proc");
            var      enumerator = procdir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
            FileInfo info = null;
            while ((info = enumerator.next_file(null)) != null) {
                if (info.get_file_type() != FileType.DIRECTORY) {
                    continue;
                }
                var statusFile = GLib.File.new_build_filename("/proc", info.get_name(), "status");
                if (!statusFile.query_exists(null)) {
                    continue;
                }
                var is = statusFile.read(null);
                Bytes     data;
                ByteArray buffer = new ByteArray();
                while (true) {
                    data = is.read_bytes(1024, null);
                    if (data.get_size() == 0) {
                        break;
                    }
                    buffer.append(data.get_data());
                }
                buffer.append({ 0 });
                var lines = ((string) buffer.data).split("\n");
                foreach (var line in lines) {
                    if (line.has_prefix("PPid:")) {
                        var ppid = int.parse(line.substring(5));
                        if (ppid == this.pid) {
                            return true;
                        }
                    }
                }
            }
            return false;
        }

        private void
        kill_child()
        {
            if (!this.has_child_running()) {
                Posix.kill(this.pid, Posix.Signal.KILL);
            } else {
                this.top_container.ask_kill_childs(_("This terminal has a process running inside."),
                                                   _("Closing it will kill the process."),
                                                   _("Close terminal"),
                                                   this);
            }
        }

        public void
        kill_all_children()
        {
            Posix.kill(this.pid, Posix.Signal.KILL);
        }

        public bool
        update_title_cb()
        {
            this.update_title();
            return false;
        }

        public void
        settings_changed(string key)
        {
            Gdk.RGBA ?color = null;
            string color_string;
            if (key.has_suffix("-color")) {
                color_string = Terminus.settings.get_string(key);
                if (color_string != "") {
                    color = Gdk.RGBA();
                    if (false == color.parse(color_string)) {
                        color = null;
                    }
                }
            } else {
                color_string = "";
            }

            switch (key) {
            case "infinite-scroll":
            case "scroll-lines":
                var lines = Terminus.settings.get_uint("scroll-lines");
                var infinite = Terminus.settings.get_boolean("infinite-scroll");
                if (infinite) {
                    lines = -1;
                }
                this.vte_terminal.scrollback_lines = lines;
                break;

            case "cursor-shape":
                var v = Terminus.settings.get_int("cursor-shape");
                if (v == 0) {
                    this.vte_terminal.cursor_shape = Vte.CursorShape.BLOCK;
                } else if (v == 1) {
                    this.vte_terminal.cursor_shape = Vte.CursorShape.IBEAM;
                } else if (v == 2) {
                    this.vte_terminal.cursor_shape = Vte.CursorShape.UNDERLINE;
                }
                break;

            case "terminal-bell":
                this.vte_terminal.audible_bell = Terminus.settings.get_boolean(key);
                break;

            case "fg-color":
                this.vte_terminal.set_color_foreground(color);
                this.fg_r = color.red;
                this.fg_g = color.green;
                this.fg_b = color.blue;
                break;

            case "bg-color":
                this.vte_terminal.set_color_background(color);
                break;

            case "focused-fg-color":
            case "focused-bg-color":
            case "inactive-fg-color":
            case "inactive-bg-color":
                this.update_title();
                break;

            case "bold-color":
                this.vte_terminal.set_color_bold(color);
                break;

            case "cursor-fg-color":
                this.vte_terminal.set_color_cursor_foreground(color);
                break;

            case "cursor-bg-color":
                this.vte_terminal.set_color_cursor(color);
                break;

            case "highlight-fg-color":
                this.vte_terminal.set_color_highlight_foreground(color);
                break;

            case "highlight-bg-color":
                this.vte_terminal.set_color_highlight(color);
                break;

            case "color-palete":
                if (Terminus.check_palette()) {
                    return;
                }
                string[]   palette_string = Terminus.settings.get_strv("color-palete");
                Gdk.RGBA[] palette = {};
                foreach (var color_string2 in palette_string) {
                    var tmpcolor = Gdk.RGBA();
                    tmpcolor.parse(color_string2);
                    palette += tmpcolor;
                }
                var fgcolor = Gdk.RGBA();
                fgcolor.parse(Terminus.settings.get_string("fg-color"));
                var bgcolor = Gdk.RGBA();
                bgcolor.parse(Terminus.settings.get_string("bg-color"));
                this.vte_terminal.set_colors(fgcolor, bgcolor, palette);
                this.settings_changed("bold-color");
                this.settings_changed("cursor-fg-color");
                this.settings_changed("cursor-bg-color");
                this.settings_changed("highlight-fg-color");
                this.settings_changed("highlight-bg-color");
                break;

            case "use-system-font":
            case "terminal-font":
                var system_font = Terminus.settings.get_boolean("use-system-font");
                Pango.FontDescription ?font_desc;
                if (system_font) {
                    font_desc = null;
                } else {
                    var font = Terminus.settings.get_string("terminal-font");
                    font_desc = Pango.FontDescription.from_string(font);
                }
                this.vte_terminal.set_font(font_desc);
                break;

            case "pointer-autohide" :
                vte_terminal.pointer_autohide = Terminus.settings.get_boolean("pointer-autohide");
                break;

            default:
                break;
            }
        }

        public bool
        on_scroll(Gdk.EventScroll event)
        {
            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (event.delta_y < 0) {
                    change_zoom(true);
                } else {
                    change_zoom(false);
                }
                return true;
            }
            return false;
        }

        private void
        change_zoom(bool increase)
        {
            if (increase) {
                this.vte_terminal.font_scale *= 1.1;
            } else {
                if (this.vte_terminal.font_scale > 0.1) {
                    this.vte_terminal.font_scale /= 1.1;
                }
            }
        }

        public bool
        on_key_press(Gdk.EventKey event)
        {
            Gdk.EventKey eventkey = event.key;
            // SHIFT, CTRL, LEFT ALT, ALT+GR
            eventkey.state &= Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK |
                              Gdk.ModifierType.MOD5_MASK;

            if (eventkey.keyval < 128) {
                // to avoid problems with upper and lower case
                eventkey.keyval &= ~32;
            }

            switch (key_bindings.find_key(eventkey)) {
            case "new-window":
                this.main_container.new_terminal_window();
                return true;

            case "new-tab":
                this.main_container.new_terminal_tab("", null);
                return true;

            case "next-tab":
                this.main_container.next_tab();
                return true;

            case "previous-tab":
                this.main_container.prev_tab();
                return true;

            case "copy":
                this.do_copy();
                return true;

            case "paste":
                this.do_paste();
                return true;

            case "terminal-up":
                this.container.move_terminal_focus(Terminus.MoveFocus.UP, null, true);
                return true;

            case "terminal-down":
                this.container.move_terminal_focus(Terminus.MoveFocus.DOWN, null, true);
                return true;

            case "terminal-left":
                this.container.move_terminal_focus(Terminus.MoveFocus.LEFT, null, true);
                return true;

            case "terminal-right":
                this.container.move_terminal_focus(Terminus.MoveFocus.RIGHT, null, true);
                return true;

            case "font-size-big":
                this.change_zoom(true);
                return true;

            case "font-size-small":
                this.change_zoom(false);
                return true;

            case "font-size-normal":
                this.vte_terminal.font_scale = 1;
                return true;

            case "show-menu":
                this.item_copy.sensitive = this.vte_terminal.get_has_selection();
                this.menu_container.popup_at_widget(this.vte_terminal, Gdk.Gravity.CENTER, Gdk.Gravity.CENTER, event);
                return true;

            case "split-horizontally":
                this.split_terminal(SplitAt.BOTTOM, null);
                return true;

            case "split-vertically":
                this.split_terminal(SplitAt.RIGHT, null);
                return true;

            case "close-tile":
                this.kill_child();
                return true;

            case "close-tab":
                this.top_container.ask_close_tab();
                return true;

            case "select-all":
                this.vte_terminal.select_all();
                return true;

            default:
                return false;
            }
        }

        private void
        update_title()
        {
            string s_title = this.vte_terminal.get_window_title();
            if ((s_title == null) || (s_title == "")) {
                s_title = this.vte_terminal.get_current_file_uri();
            }
            if ((s_title == null) || (s_title == "")) {
                s_title = this.vte_terminal.get_current_directory_uri();
            }
            if ((s_title == null) || (s_title == "")) {
                s_title = "/bin/bash";
            }
            this.top_container.set_tab_title(s_title);

            string fg;
            string bg;
            var    tmp_color = Gdk.RGBA();
            if (this.vte_terminal.has_focus) {
                fg = Terminus.settings.get_string("focused-fg-color");
                bg = Terminus.settings.get_string("focused-bg-color");
            } else {
                fg = Terminus.settings.get_string("inactive-fg-color");
                bg = Terminus.settings.get_string("inactive-bg-color");
            }
            tmp_color.parse(bg);
            this.title_r = tmp_color.red;
            this.title_g = tmp_color.green;
            this.title_b = tmp_color.blue;
            this.title.use_markup = true;
            this.title.label = "<span foreground=\"%s\" background=\"%s\" size=\"small\">%s %ldx%ld</span>".printf(fg,
                                                                                                                   bg,
                                                                                                                   s_title,
                                                                                                                   this.vte_terminal.get_column_count(),
                                                                                                                   this.vte_terminal.get_row_count());
            this.titlebox.queue_draw();
        }

        public bool
        button_event(Gdk.EventButton event)
        {
            if (event.button == 3) {
                this.item_copy.sensitive = this.vte_terminal.get_has_selection();
                this.menu_container.popup_at_pointer(event);
                return true;
            }
            if ((event.button == 2) && ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
                this.vte_terminal.font_scale = 1;
                return true;
            }
            return false;
        }
    }
}
