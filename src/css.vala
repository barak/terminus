/*
 * Copyright 2016-2024 (C) Raster Software Vigo (Sergio Costas)
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
    class CssManager {
        private Gtk.CssProvider ?css_provider = null;

        public CssManager()
        {
            Terminus.settings.changed.connect(this.settings_changed);
            this.update_css();
        }

        private void
        settings_changed(string key)
        {
            string settings_list[] = {
                "fg-color",         "bg-color",         "inactive-bg-color",         "inactive-fg-color",
                "focused-bg-color", "focused-fg-color", "focused-root-bg-color",     "focused-root-fg-color",
                "terminal-font"
            };
            if (key in settings_list) {
                this.update_css();
            }
        }

        private void
        update_css()
        {
            if (this.css_provider != null) {
                Gtk.StyleContext.remove_provider_for_display(Gdk.Display.get_default(), this.css_provider);
            }
            var    fg_color = Terminus.settings.get_string("fg-color");
            var    bg_color = Terminus.settings.get_string("bg-color");
            var    font_desc = Pango.FontDescription.from_string(Terminus.settings.get_string("terminal-font"));
            var    font_family = font_desc.get_family();
            var    font_size_value = font_desc.get_size() / 1000;
            string font_size;
            if (font_desc.get_size_is_absolute()) {
                font_size = "%dpx".printf(font_size_value);
            } else {
                font_size = "%dpt".printf(font_size_value);
            }
            font_size = font_size.replace(",", ".");
            string font_style;
            switch (font_desc.get_style()) {
            default:
                font_style = "normal";
                break;

            case Pango.Style.ITALIC:
                font_style = "italic";
                break;

            case Pango.Style.OBLIQUE:
                font_style = "oblique";
                break;
            }
            string font_weight;
            switch (font_desc.get_weight()) {
            default:
                font_weight = "normal";
                break;

            case Pango.Weight.MEDIUM:
                font_weight = "medium";
                break;

            case Pango.Weight.BOLD:
                font_weight = "bold";
                break;

            case Pango.Weight.SEMIBOLD:
                font_weight = "semibold";
                break;

            case Pango.Weight.ULTRALIGHT:
                font_weight = "ultralight";
                break;

            case Pango.Weight.LIGHT:
                font_weight = "light";
                break;
            }

            var focused_fg_color = Terminus.settings.get_string("focused-fg-color");
            var focused_bg_color = Terminus.settings.get_string("focused-bg-color");
            var focused_root_fg_color = Terminus.settings.get_string("focused-root-fg-color");
            var focused_root_bg_color = Terminus.settings.get_string("focused-root-bg-color");
            var inactive_fg_color = Terminus.settings.get_string("inactive-fg-color");
            var inactive_bg_color = Terminus.settings.get_string("inactive-bg-color");
            this.css_provider = new Gtk.CssProvider();
            var css = "";
            css +=
                @".dndbottom {background: linear-gradient(0deg, $fg_color 0%, $fg_color 49%, $bg_color 51%, $bg_color 100%);}\n";
            css +=
                @".dndleft {background: linear-gradient(90deg, $fg_color 0%, $fg_color 49%, $bg_color 51%, $bg_color 100%);}\n";
            css +=
                @".dndtop {background: linear-gradient(180deg, $fg_color 0%, $fg_color 49%, $bg_color 51%, $bg_color 100%);}\n";
            css +=
                @".dndright {background: linear-gradient(270deg, $fg_color 0%, $fg_color 49%, $bg_color 51%, $bg_color 100%);}\n";
            css += @".terminaltitlefocused {background-color: $focused_bg_color; color: $focused_fg_color;}\n";
            css +=
                @".terminaltitlerootfocused {background-color: $focused_root_bg_color; color: $focused_root_fg_color;}\n";
            css += @".terminaltitleinactive {background-color: $inactive_bg_color; color: $inactive_fg_color;}\n";
            css +=
                @".terminalbase {background-color: $bg_color; color: $fg_color; font-family: $font_family; font-size: $font_size; font-style: $font_style; font-weight: $font_weight;}\n";

            this.css_provider.load_from_string(css);
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        }
    }
}
