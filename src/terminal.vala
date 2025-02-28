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

    uint32 RegExMultilineFlag = 0x0400;

    public class Terminal : Gtk.Box, Killable, DnDDestination {
        private int pid;
        private Vte.Terminal vte_terminal;
        private Gtk.Label title;
        private Gtk.GestureClick click_controller_1;
        private Gtk.EventControllerKey key_controller;
        private weak Terminus.Container top_container;
        private weak Terminus.Container container;
        private weak Terminus.Base main_container;
        private Gtk.Scrollbar right_scroll;
        private SplitAt split_mode;
        private string last_css = "";
        private string last_title_css = "";
        private bool had_focus;
        private bool bell = false;
        private Gtk.Box search_bar;
        private Gtk.Entry search_entry;
        private Gtk.CheckButton search_is_regex;
        private string[] regex_special_chars = {
            "\\", "^", "$", ".", "|", "?", "*", "+", "(", ")", "{", "}", "[", "]"
        };

        public signal void
        ended(Terminus.Terminal terminal);
        public signal void
        split_terminal(SplitAt            where,
                       Terminus.Terminal ?new_terminal,
                       string ?           path);

        public Terminus.Terminal ?find_terminal_by_pid(int pid)
        {
            if (pid == this.pid) {
                return this;
            } else {
                return null;
            }
        }

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
        drop_terminal(Terminal terminal)
        {
            this.split_terminal(this.split_mode, terminal, null);
            this.split_mode = SplitAt.NONE;
        }

        public void
        do_select_all()
        {
            this.vte_terminal.select_all();
        }

        public void
        do_split_horizontally()
        {
            this.split_terminal(SplitAt.BOTTOM, null, this.get_current_path());
        }

        public void
        do_split_vertically()
        {
            this.split_terminal(SplitAt.RIGHT, null, this.get_current_path());
        }

        public void
        do_new_tab()
        {
            this.main_container.new_terminal_tab("", null);
        }

        public void
        do_new_window()
        {
            this.main_container.new_terminal_window();
        }

        public void
        do_close()
        {
            this.kill_child();
        }

        public void
        do_copy()
        {
            this.vte_terminal.copy_clipboard_format(Vte.Format.TEXT);
        }

        public async void
        do_paste()
        {
            var clipboard = this.vte_terminal.get_clipboard();
            var text = yield clipboard.
                       read_text_async(null);

            this.vte_terminal.paste_text(text);
        }

        public void
        do_reset()
        {
            this.vte_terminal.reset(true, false);
        }

        public void
        do_reset_clear()
        {
            this.vte_terminal.reset(true, true);
        }

        private void
        new_menu_element(string     text,
                         string     action,
                         GLib.Menu ?menu)
        {
            var item = new GLib.MenuItem(text, null);
            item.set_action_and_target_value("app." + action, new Variant.int32(this.pid));
            menu.append_item(item);
        }

        private GLib.Menu
        new_section(GLib.Menu menu)
        {
            var section = new GLib.Menu();
            menu.append_section(null, section);
            return section;
        }

        private GLib.Menu
        create_menu()
        {
            var menu_container = new GLib.Menu();
            var section1 = new_section(menu_container);
            this.new_menu_element(_("Copy"), "copy", section1);
            this.new_menu_element(_("Paste"), "paste", section1);

            var section2 = new_section(menu_container);
            this.new_menu_element(_("Select all"), "select-all", section2);

            var section3 = new_section(menu_container);

            this.new_menu_element(_("Split horizontally"),
                                  "hsplit",
                                  section3);
            this.new_menu_element(_("Split vertically"),
                                  "vsplit",
                                  section3);

            var section4 = new_section(menu_container);
            this.new_menu_element(_("New tab"), "new-tab", section4);
            this.new_menu_element(_("New window"), "new-window", section4);

            var section5 = new_section(menu_container);

            var submenu = new GLib.Menu();

            section5.append_submenu(_("Extra"), submenu);

            this.new_menu_element(_("Reset terminal"), "reset-terminal", submenu);
            this.new_menu_element(_("Reset and clear terminal"), "reset-clear-terminal", submenu);

            var section6 = new_section(menu_container);

            this.new_menu_element(_("Preferences"), "preferences", section6);

            var section7 = new_section(menu_container);

            this.new_menu_element(_("Close"), "close", section7);
            return menu_container;
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

        public Terminal(Terminus.Base      main_container,
                        string             working_directory,
                        string[] ?         commands,
                        Terminus.Container top_container,
                        Terminus.Container container)
        {
            this.container = container;
            // when creating a new terminal, it must take the focus
            had_focus = true;
            this.split_mode = SplitAt.NONE;
            this.map.connect_after(() => {
                // this ensures that the title is updated when the window is shown
                GLib.Timeout.add_once(200, () => {
                    this.update_title();
                });
            });

            this.main_container = main_container;
            this.top_container = top_container;
            this.orientation = Gtk.Orientation.VERTICAL;

            this.title = new Gtk.Label("");
            title.hexpand = true;
            title.halign = Gtk.Align.FILL;

            var close_terminal = new Gtk.Image.from_icon_name("window-close-symbolic");
            var controller = new Gtk.GestureClick();
            close_terminal.add_controller(controller);

            controller.released.connect(() => {
                this.kill_child();
            });

            var do_search = new Gtk.Image.from_icon_name("system-search-symbolic");
            var controller_search = new Gtk.GestureClick();
            do_search.add_controller(controller_search);

            controller_search.released.connect(() => {
                this.switch_search_visibility();
            });

            var titleContainer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            titleContainer.append(do_search);
            titleContainer.append(this.title);
            titleContainer.append(close_terminal);

            var terminal_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.append(titleContainer);
            this.append(terminal_box);

            this.vte_terminal = new Vte.Terminal();
            this.vte_terminal.hexpand = true;
            this.vte_terminal.vexpand = true;
            this.hexpand = true;
            this.vexpand = true;
            // regex for URIs: search for anything that begins with http:// or https:// and continues until
            // a blank space, but remove any period, comma, colon or semicolon at the end.
            var regex = new Vte.Regex.for_match("https?://.+?(?= |: |; |, |\\. )", -1, RegExMultilineFlag);
            var tag_regex = this.vte_terminal.match_add_regex(regex, 0);
            this.vte_terminal.match_set_cursor_name(tag_regex, "pointer");

            this.vte_terminal.window_title_changed.connect_after(() => {
                this.update_title();
            });
            var focus_controller = new Gtk.EventControllerFocus();
            focus_controller.propagation_phase = Gtk.PropagationPhase.BUBBLE;
            this.vte_terminal.add_controller(focus_controller);
            focus_controller.enter.connect(() => {
                this.had_focus = true;
                this.update_title_color();
                this.top_container.set_last_focus(this);
            });
            focus_controller.leave.connect(() => {
                this.had_focus = false;
                this.update_title_color();
            });
            this.vte_terminal.notify.connect((pspec) => {
                this.update_title();
            });
            this.vte_terminal.map.connect_after((w) => {
                if (this.had_focus) {
                    GLib.Timeout.add_once(200, () => {
                        this.vte_terminal.grab_focus();
                    });
                }
            });
            this.vte_terminal.allow_hyperlink = true;

            Terminus.settings.bind("scroll-on-output",
                                   this.vte_terminal,
                                   "scroll_on_output",
                                   GLib.SettingsBindFlags.DEFAULT);
            Terminus.settings.bind("scroll-on-keystroke",
                                   this.vte_terminal,
                                   "scroll_on_keystroke",
                                   GLib.SettingsBindFlags.DEFAULT);

            this.right_scroll = new Gtk.Scrollbar(Gtk.Orientation.VERTICAL, this.vte_terminal.vadjustment);

            terminal_box.append(this.vte_terminal);
            terminal_box.append(right_scroll);

            this.search_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.search_entry = new Gtk.Entry();
            this.search_is_regex = new Gtk.CheckButton.with_label(_("Use regular expressions"));
            var prev_search = new Gtk.Button.from_icon_name("go-previous");
            var next_search = new Gtk.Button.from_icon_name("go-next");
            this.vte_terminal.search_set_wrap_around(true);

            this.search_entry.changed.connect(() => {
                this.update_search();
            });

            this.search_is_regex.toggled.connect(() => {
                this.update_search();
            });

            this.search_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "system-search-symbolic");

            prev_search.clicked.connect(() => {
                this.vte_terminal.search_find_previous();
            });
            next_search.clicked.connect(() => {
                this.vte_terminal.search_find_next();
            });

            this.search_bar.append(this.search_entry);
            this.search_bar.append(prev_search);
            this.search_bar.append(next_search);
            this.search_bar.append(search_is_regex);
            this.append(search_bar);

            var search_key_controller = new Gtk.EventControllerKey();
            this.search_entry.add_controller(search_key_controller);
            search_key_controller.key_pressed.connect((controller, keyval, keycode, state) => {
                switch (keyval) {
                    case Gdk.Key.Escape:
                        this.hide_search();
                        return true;

                    case Gdk.Key.Return:
                        if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                            this.vte_terminal.search_find_previous();
                        } else {
                            this.vte_terminal.search_find_next();
                        }
                        return true;

                    default:
                        return false;
                }
            });
            this.search_entry.activate.connect(() => {
                this.vte_terminal.search_find_next();
            });

            string[] cmd = {};
            if (Terminus.settings.get_boolean("use-custom-shell")) {
                cmd += Terminus.settings.get_string("shell-command");
            } else {
                bool                 found = false;
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
            var environment = GLib.Environ.set_variable(GLib.Environ.get(), "TERM", "xterm-256color", true);
            this.pid = 0;
            this.vte_terminal.spawn_async(Vte.PtyFlags.DEFAULT,
                                          working_directory,
                                          cmd,
                                          environment,
                                          0,
                                          null,
                                          -1,
                                          null,
                                          (terminal, pid, error) => {
                this.pid = pid;
                // the menu depends on the pid, so we must create it here
                var menu = new Gtk.PopoverMenu.from_model_full(this.create_menu(), Gtk.PopoverMenuFlags.NESTED);
                this.vte_terminal.set_context_menu(menu);
                menu.map.connect(() => {
                    this.top_container.set_copy_enabled(this.vte_terminal.get_has_selection());
                });
            });
            this.vte_terminal.child_exited.connect(() => {
                this.top_container.terminal_ended(this);
                this.ended(this);
            });

            this.vte_terminal.bell.connect(() => {
                if (this.bell) {
                    return;
                }
                this.bell = true;
                this.update_title_color();
                GLib.Timeout.add_once(200, () => {
                    this.bell = false;
                    this.update_title_color();
                });
            });

            this.click_controller_1 = new Gtk.GestureClick();
            this.click_controller_1.button = 1;
            this.key_controller = new Gtk.EventControllerKey();

            this.vte_terminal.add_controller(this.click_controller_1);
            this.vte_terminal.add_controller(this.key_controller);
            this.key_controller.key_pressed.connect(this.on_key_press);
            this.click_controller_1.pressed.connect(this.button_1_event);
            Terminus.settings.changed.connect(this.settings_changed);

            this.update_title();
            GLib.Timeout.add(500, () => {
                this.update_title_color(); // to check for childs running as root
                return true;
            });

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

            var drag_source = new Gtk.DragSource();
            this.title.add_controller(drag_source);
            drag_source.prepare.connect((source, x, y) => {
                var drag_value = Value(typeof(Terminus.Terminal));
                drag_value.set_object(this);
                return new Gdk.ContentProvider.for_value(drag_value);
            });
            drag_source.drag_cancel.connect((source, drag, reason) => {
                // drop outside, in a new window
                this.extract_from_container();
                main_root.create_window(false, null, null, this);
                return true;
            });

            var drop_target_terminal = new Gtk.DropTarget(typeof(Terminus.Terminal),
                                                          Gdk.DragAction.COPY | Gdk.DragAction.MOVE |
                                                          Gdk.DragAction.LINK);
            this.vte_terminal.add_controller(drop_target_terminal);
            drop_target_terminal.drop.connect((target, drag_value, x, y) => {
                this.vte_terminal.set_clear_background(true);
                if (this.last_css != "") {
                    this.vte_terminal.remove_css_class(this.last_css);
                    this.last_css = "";
                }
                var terminal = drag_value as Terminus.Terminal;
                terminal.drop_terminal_into(this);
                return true;
            });
            drop_target_terminal.motion.connect((target, x, y) => {
                this.vte_terminal.set_clear_background(false);
                var nx = 2.0 * x / this.vte_terminal.get_width() - 1.0;
                var ny = 2.0 * y / this.vte_terminal.get_height() - 1.0;
                SplitAt new_split_mode = SplitAt.NONE;
                var new_css = "";
                if (ny <= nx) {
                    if (ny <= (-nx)) {
                        new_split_mode = SplitAt.TOP;
                        new_css = "dndtop";
                    } else {
                        new_split_mode = SplitAt.RIGHT;
                        new_css = "dndright";
                    }
                } else {
                    if (ny <= (-nx)) {
                        new_split_mode = SplitAt.LEFT;
                        new_css = "dndleft";
                    } else {
                        new_split_mode = SplitAt.BOTTOM;
                        new_css = "dndbottom";
                    }
                }
                if (this.split_mode != new_split_mode) {
                    if (this.last_css != "") {
                        this.vte_terminal.remove_css_class(this.last_css);
                    }
                    this.vte_terminal.add_css_class(new_css);
                    this.split_mode = new_split_mode;
                    this.last_css = new_css;
                }
                return Gdk.DragAction.MOVE;
            });
            drop_target_terminal.leave.connect((target) => {
                this.vte_terminal.set_clear_background(true);
                if (this.last_css != "") {
                    this.vte_terminal.remove_css_class(this.last_css);
                    this.last_css = "";
                }
                this.split_mode = SplitAt.NONE;
            });
            this.set_visible(true);
            this.hide_search();
        }

        private void
        update_search()
        {
            var search = this.search_entry.get_buffer().get_text();
            if (!this.search_is_regex.get_active()) {
                // escape all the regex special chars
                foreach (var ch in this.regex_special_chars) {
                    search = search.replace(ch, "\\" + ch);
                }
            }

            Vte.Regex ?search_regex = null;
            try {
                search_regex = new Vte.Regex.for_search(search, -1, RegExMultilineFlag);
                this.search_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, null);
            } catch(Error e) {
                this.search_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, "dialog-error");
            }
            this.vte_terminal.search_set_regex(search_regex, 0);
        }

        private void
        hide_search()
        {
            this.search_bar.set_visible(false);
            this.vte_terminal.grab_focus();
        }

        private void
        show_search()
        {
            this.search_bar.set_visible(true);
            this.search_entry.grab_focus_without_selecting();
        }

        private void
        switch_search_visibility()
        {
            if (this.search_bar.visible) {
                this.hide_search();
            } else {
                this.show_search();
            }
        }

        public void
        drop_terminal_into(Terminus.DnDDestination destination)
        {
            if (destination == this) {
                return;
            }
            var old_container = this.container;
            this.container.extract_current_terminal();
            destination.drop_terminal(this);
            old_container.ended_cb();
        }

        public string ?
        get_current_path()
        {
            var procPath = "/proc/%d/cwd".printf(this.pid);
            var cwdFile = GLib.File.new_for_path(procPath);
            var cwdFileInfo = cwdFile.query_info(GLib.FileAttribute.STANDARD_SYMLINK_TARGET,
                                                 GLib.FileQueryInfoFlags.NONE,
                                                 null);
            return cwdFileInfo.get_symlink_target();
        }

        public bool
        has_child_running()
        {
            return Terminus.processes.has_running_child(this.pid);
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

        public void
        settings_changed(string key)
        {
            Gdk.RGBA ?color = null;
            string    color_string;
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
                var                    system_font = Terminus.settings.get_boolean("use-system-font");
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
        on_key_press(Gtk.EventControllerKey key_controller,
                     uint                   keyval,
                     uint                   keycode,
                     Gdk.ModifierType       state)
        {
            // SHIFT, CTRL, LEFT ALT, ALT+GR
            state &= Gdk.ModifierType.SHIFT_MASK |
                     Gdk.ModifierType.CONTROL_MASK |
                     Gdk.ModifierType.SUPER_MASK |
                     Gdk.ModifierType.META_MASK |
                     Gdk.ModifierType.HYPER_MASK |
                     Gdk.ModifierType.ALT_MASK;

            if (keyval == Gdk.Key.Escape) {
                this.hide_search();
            }

            if ((keyval <= 'z') && (keyval >= 'a')) {
                // to avoid problems with upper and lower case
                keyval &= ~32;
            }

            switch (key_bindings.find_key(keyval, state)) {
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

            case "split-horizontally":
                this.split_terminal(SplitAt.BOTTOM, null, this.get_current_path());
                return true;

            case "split-vertically":
                this.split_terminal(SplitAt.RIGHT, null, this.get_current_path());
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

            case "search":
                this.switch_search_visibility();
                return true;
            }

            var command = Terminus.macros.check_macro(keyval, state);
            if (command != null) {
                this.vte_terminal.feed_child((uint8[]) command.to_utf8());
                return true;
            }
            return false;
        }

        public void
        close()
        {
        }

        private void
        update_title_color()
        {
            if (this.last_title_css != "") {
                this.title.remove_css_class(this.last_title_css);
            }
            this.last_title_css = "terminaltitle" +
                                  ((this.had_focus ^
                                    this.bell) ? (Terminus.processes.has_root_child(this.pid) ? "rootfocused" :
                                                  "focused") : "inactive");
            this.title.add_css_class(this.last_title_css);
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

            this.title.use_markup = true;
            this.title.label = "<span size=\"small\">%s %ldx%ld</span>".printf(s_title,
                                                                               this.vte_terminal.get_column_count(),
                                                                               this.vte_terminal.get_row_count());
            this.update_title_color();
        }

        public void
        button_1_event(Gtk.GestureClick gesture,
                       int              npress,
                       double           x,
                       double           y)
        {
            if (npress != 1) {
                return;
            }
            if (this.vte_terminal.hyperlink_hover_uri != null) {
                GLib.AppInfo.launch_default_for_uri(this.vte_terminal.hyperlink_hover_uri, null);
                return;
            }
            int tag;
            var uri = this.vte_terminal.check_match_at(x, y, out tag);
            if (uri != null) {
                GLib.AppInfo.launch_default_for_uri(uri, null);
                return;
            }
        }
    }
}
