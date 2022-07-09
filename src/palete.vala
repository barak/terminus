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

using Gee;

namespace Terminus {
    public class Terminuspalette : Object {
        public bool custom;
        public string ?name;
        public HashMap<string, string> name_locale;
        private Gdk.RGBA[] palette;
        public Gdk.RGBA ?text_fg;
        public Gdk.RGBA ?text_bg;


        public Terminuspalette()
        {
            this.name = null;
            this.palette = {};
            this.text_fg = null;
            this.text_bg = null;
            this.name_locale = new HashMap<string, string>();
            this.custom = false;
        }

        public Gdk.RGBA[]
        get_palette()
        {
            return this.palette;
        }

        public bool
        compare_scheme()
        {
            if (this.custom) {
                return false;
            }

            if (this.text_fg == null) {
                return false;
            }

            var color = Gdk.RGBA();

            color.parse(Terminus.settings.get_string("fg-color"));
            if (!this.text_fg.equal(color)) {
                return false;
            }
            color.parse(Terminus.settings.get_string("bg-color"));
            if (!this.text_bg.equal(color)) {
                return false;
            }

            return true;
        }

        public bool
        compare_palette()
        {
            string[] current = Terminus.settings.get_strv("color-palete");
            if (current.length != this.palette.length) {
                return false;
            }
            for (int i = 0; i < 16; i++) {
                string color =
                    "#%02X%02X%02X".printf((int) (this.palette[i].red * 255),
                                           (int) (this.palette[i].green * 255),
                                           (int) (this.palette[i].blue * 255));
                if (current[i].ascii_up() != color) {
                    return false;
                }
            }
            return true;
        }

        public bool
        readpalette(string filename)
        {
            if (!filename.has_suffix(".color_scheme")) {
                return true;
            }

            var file = File.new_for_path(filename);

            if (!file.query_exists()) {
                return true;
            }
            bool has_more = false;
            int  line_n = 0;
            bool has_error = false;
            try {
                var    dis = new DataInputStream(file.read());
                string line;
                while ((line = dis.read_line(null)) != null) {
                    line_n++;
                    line = line.strip();
                    if (line.length == 0) {
                        continue;
                    }
                    if (line[0] == '#') {
                        continue;
                    }
                    var pos = line.index_of_char(':');
                    if (pos == -1) {
                        GLib.stderr.printf(_("Error: palette file %s has unrecognized content at line %d\n"),
                                           filename,
                                           line_n);
                        has_error = true;
                        continue;
                    }
                    var command = line.substring(0, pos).strip();
                    var sdata = line.substring(pos + 1).strip();
                    if (command == "name") {
                        this.name = sdata;
                        continue;
                    }
                    if (command.has_prefix("name[")) {
                        var p = command.index_of_char(']');
                        if (p == -1) {
                            GLib.stderr.printf(_(
                                                   "Error: palette file %s has opens a bracket at line %d without closing it\n"),
                                               filename,
                                               line_n);
                            has_error = true;
                            continue;
                        }
                        var lang = command.substring(5, p - 5);
                        this.name_locale[lang] = sdata;
                        continue;
                    }
                    if (sdata[0] != '#') {
                        sdata = "#" + sdata;
                    }
                    var data = Gdk.RGBA();
                    if (!data.parse(sdata)) {
                        GLib.stderr.printf(_("Error: palette file %s has an unrecognized color at line %d\n"),
                                           filename,
                                           line_n);
                        has_error = true;
                        continue;
                    }
                    switch (command) {
                    case "palette":
                        if (this.palette.length < 16) {
                            this.palette += data;
                        } else {
                            if (!has_more) {
                                GLib.stderr.printf(_("Warning: palette file %s has more than 16 colors\n"), filename);
                            }
                            has_more = true;
                        }
                        break;

                    case "text_fg":
                        this.text_fg = data;
                        break;

                    case "text_bg":
                        this.text_bg = data;
                        break;

                    default:
                        GLib.stderr.printf(_("Error: palette file %s has unrecognized content at line %d\n"),
                                           filename,
                                           line_n);
                        has_error = true;
                        break;
                    }
                }
            } catch(Error e) {
                return true;
            }

            if ((this.palette.length > 0) && (this.palette.length < 16)) {
                GLib.stdout.printf(_("Error: Palette file %s has less than 16 colors\n"), filename);
                has_error = true;
            }
            if ((this.name == null) || (this.name == "")) {
                GLib.stdout.printf(_("Error: Palette file %s has no palette name\n"), filename);
                has_error = true;
            }
            if ((this.text_bg == null) && (this.text_fg != null)) {
                GLib.stdout.printf(_("Error: Palette file %s has text_fg color but not text_bg color\n"), filename);
                has_error = true;
            }
            if ((this.text_bg != null) && (this.text_fg == null)) {
                GLib.stdout.printf(_("Error: Palette file %s has text_bg color but not text_fg color\n"), filename);
                has_error = true;
            }

            foreach (var locale in GLib.Intl.get_language_names()) {
                if (this.name_locale.has_key(locale)) {
                    this.name = this.name_locale.get(locale);
                    break;
                }
            }
            return has_error;
        }
    }
}
