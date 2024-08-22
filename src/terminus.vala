/*
 * Copyright 2016-2022 (C) Raster Software Vigo (Sergio Costas)
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

using Gtk;
using Gee;

namespace Terminus {
    TerminusRoot     main_root;
    DnDManager       dnd_manager;
    KeyBindings      key_bindings;
    Macros           macros;
    GLib.Settings    settings = null;
    GLib.Settings    keybind_settings = null;
    Terminus.Bindkey bindkey;

    public class TerminusRoot : Gtk.Application {
        private Gee.List<Terminus.Window> window_list;
        private Terminus.Base ?guake_terminal = null;
        private Terminus.Window ?guake_window = null;
        private string ?guake_title = null;
        private bool executed_hold = false;

        private Terminus.Parameters ?parameters = null;

        public Gee.List<Terminuspalette> palettes;

        private Terminus.Properties ?window_properties = null;

        public TerminusRoot()
        {
            Object(application_id: "com.rastersoft.terminus",
                   flags : GLib.ApplicationFlags.HANDLES_COMMAND_LINE);

            this.window_list = new Gee.ArrayList<Terminus.Window>();

            this.palettes = new Gee.ArrayList<Terminuspalette>();
            this.startup.connect(this.do_startup);
            this.command_line.connect(this.do_command_line);
        }

        protected override bool
        local_command_line(ref weak string[] parameters,
                           out int           retval)
        {
            var params = new Terminus.Parameters();
            retval = 0;
            if (!params.parse_argv(parameters)) {
                retval = 1;
                return true;
            }
            if (params.version) {
                print(_("Version %s\n".printf(Constants.VERSION)));
                return true;
            }
            if (params.help) {
                Terminus.show_usage();
                return true;
            }
            if (params.read_uuid) {
                try {
                    var stdinInput = new GLib.DataInputStream(new GLib.UnixInputStream(0, false));
                    this.guake_title = stdinInput.read_line();
                    stdinInput.close();
                } catch(GLib.IOError e) {
                    print("Error while reading STDIN. Exiting.\n");
                    return true;
                }
            }
            if (params.check_guake && (
                    (GLib.Environment.get_variable("XDG_CURRENT_DESKTOP").index_of("GNOME") != -1) || // under Gnome Shell and family always rely on the extension
                    (Terminus.settings.get_boolean("enable-guake-mode") == false)) ||                 // if Guake mode is disabled, don't launch it
                (PrivateVapi.check_wayland() != 0)                                                                // don't launch it if we are in Wayland
                ) {
                return true;
            }
            return false;
        }

        protected void
        do_startup()
        {
            Terminus.key_bindings = new Terminus.KeyBindings();
            Terminus.macros = new Terminus.Macros();
            this.read_color_schemes(GLib.Path.build_filename(Constants.DATADIR, "terminus"));
            this.read_color_schemes(GLib.Path.build_filename(Environment.get_home_dir(),
                                                             ".local",
                                                             "share",
                                                             "terminus"));

            var palette = new Terminus.Terminuspalette();
            palette.custom = true;
            palette.name = _("Custom colors");
            this.palettes.add(palette);
            this.palettes.sort(this.ComparePalettes);

            var show_guake = new GLib.SimpleAction("show_guake", null);
            show_guake.activate.connect(() => {
                this.show_hide_global(0);
            });
            this.add_action(show_guake);
            var hide_guake = new GLib.SimpleAction("hide_guake", null);
            hide_guake.activate.connect(() => {
                this.show_hide_global(1);
            });
            this.add_action(hide_guake);
            var swap_guake = new GLib.SimpleAction("swap_guake", null);
            swap_guake.activate.connect(() => {
                this.show_hide_global(2);
            });
            this.add_action(swap_guake);
            var disable_keybind = new GLib.SimpleAction("disable_keybind", null);
            disable_keybind.activate.connect(() => {
                bindkey.unset_bindkey();
            });
            this.add_action(disable_keybind);
        }

        protected int
        do_command_line(GLib.ApplicationCommandLine command_line)
        {
            var params = new Terminus.Parameters();
            params.parse_argv(command_line.get_arguments());
            if (this.parameters == null) {
                this.parameters = params;
                Terminus.bindkey = new Terminus.Bindkey(parameters.bind_keys);
            }

            if (params.no_window) {
                if (!this.executed_hold) {
                    this.hold();
                    this.executed_hold = true;
                }
            } else {
                this.create_window(false, params.working_directory, params.command);
            }
            Terminus.keybind_settings.changed.connect(this.keybind_settings_changed);
            return 0;
        }

        public int
        ComparePalettes(Terminuspalette a,
                        Terminuspalette b)
        {
            if (a.custom) {
                return -1;
            }
            if (b.custom) {
                return 1;
            }
            if (a.name < b.name) {
                return -1;
            } else {
                if (a.name > b.name) {
                    return 1;
                } else {
                    return 0;
                }
            }
        }

        public void
        show_properties()
        {
            if (this.window_properties == null) {
                this.window_properties = new Terminus.Properties();
            }
            this.window_properties.show_all();
            this.window_properties.present();
        }

        void
        read_color_schemes(string foldername)
        {
            try {
                var directory = File.new_for_path(foldername);

                var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);

                FileInfo file_info;
                while ((file_info = enumerator.next_file()) != null) {
                    var palette = new Terminuspalette();
                    if (!palette.readpalette(GLib.Path.build_filename(foldername, file_info.get_name()))) {
                        this.palettes.add(palette);
                    }
                }
            } catch(Error e) {}
        }

        public void
        keybind_settings_changed(string key)
        {
            if (key != "guake-mode") {
                return;
            }
            Terminus.bindkey.show_guake.disconnect(this.show_hide);
            Terminus.bindkey.set_bindkey(Terminus.keybind_settings.get_string("guake-mode"));
            Terminus.bindkey.show_guake.connect(this.show_hide);
        }

        public void
        create_window(bool              guake_mode,
                      string   ?        working_directory,
                      string[] ?        commands,
                      Terminus.Terminal?terminal = null)
        {
            Terminus.Window window;

            if (working_directory == null) {
                working_directory = GLib.Environment.get_home_dir();
            }
            if (guake_mode) {
                if (this.guake_terminal == null) {
                    this.guake_terminal = new Terminus.Base(GLib.Environment.get_home_dir(), null, null);
                }
                window = new Terminus.Window(this,
                                             true,
                                             working_directory,
                                             commands,
                                             this.guake_terminal,
                                             this.guake_title);
                this.guake_window = window;
                Terminus.bindkey.show_guake.connect(this.show_hide);
            } else {
                window = new Terminus.Window(this, false, working_directory, commands, null, null, terminal);
            }
            window.ended.connect((w) => {
                window_list.remove(w);
                if (w == this.guake_window) {
                    Terminus.bindkey.show_guake.disconnect(this.show_hide);
                    this.guake_window = null;
                    this.guake_terminal = null;
                    this.create_window(true, null, null);
                }
            });
            window.new_window.connect(() => {
                this.create_window(false, null, null);
            });
            window_list.add(window);
        }

        public void
        show_hide()
        {
            this.show_hide_global(2);
        }

        public void
        show_hide_global(int mode)
        {
            /* mode = 0: force show
             * mode = 1: force hide
             * mode = 2: hide if visible, show if hidden
             */

            if (Terminus.settings.get_boolean("enable-guake-mode") == false) {
                return;
            }

            if (this.guake_window == null) {
                this.create_window(true, null, null);
            }

            if (mode == 0) {
                if (!this.guake_window.visible) {
                    this.guake_window.show();
                }
                return;
            }

            if (mode == 1) {
                if (this.guake_window.visible) {
                    this.guake_window.hide();
                }
                return;
            }

            // mode 2
            if (this.guake_window.visible) {
                this.guake_window.hide();
            } else {
                if (PrivateVapi.check_wayland() == 0) {
                    this.guake_window.set_screen(Gdk.Screen.get_default());
                }
                this.guake_window.present();
            }
        }
    }

    /**
     * Ensures that the palette stored in the settings is valid
     * If not, replaces the ofending elements
     */
    bool
    check_palette()
    {
        string[] palette_string = Terminus.settings.get_strv("color-palete");
        if (palette_string.length != 16) {
            string[] tmp = {};
            for (var i = 0; i < 16; i++) {
                var color = Gdk.RGBA();
                if ((i < palette_string.length) && (color.parse(palette_string[i]))) {
                    tmp += palette_string[i];
                } else {
                    var v = (i < 8) ?0xAA : 0xFF;
                    tmp +=
                        "#%02X%02X%02X".printf(((v & 0x01) != 0 ?v : 0),
                                               ((v & 0x02) != 0 ?v : 0),
                                               ((v & 0x04) != 0 ?v : 0));
                }
            }
            Terminus.settings.set_strv("color-palete", tmp);
            return true;
        }
        return false;
    }
}

int
main(string[] argv)
{
    Intl.bindtextdomain(Constants.GETTEXT_PACKAGE, GLib.Path.build_filename(Constants.DATADIR, "locale"));

    Intl.textdomain(Constants.GETTEXT_PACKAGE);
    Intl.bind_textdomain_codeset(Constants.GETTEXT_PACKAGE, "UTF-8");

    Terminus.settings = new GLib.Settings("org.rastersoft.terminus");
    Terminus.keybind_settings = new GLib.Settings("org.rastersoft.terminus.keybindings");
    Terminus.dnd_manager = new Terminus.DnDManager();

    Terminus.check_palette();

    Terminus.main_root = new Terminus.TerminusRoot();
    Terminus.main_root.run(argv);

    return 0;
}
