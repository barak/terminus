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
using Gdk;

namespace Terminus {
    /**
     * This is a Gtk.Paned that can be set to a percentage value, instead of
     * having to use absolute values (which depends on the current size of
     * the panel).
     */

    public class PanedPercentage : Gtk.Widget {
        private Gtk.Paned ?paned = null;
        private double desired_paned_percentage;
        private bool button_pressed;
        private bool horizontal;

        public Gtk.Widget ?start_child {
            get {
                return this.paned.start_child;
            }
            set {
                this.paned.start_child = value;
            }
        }

        public Gtk.Widget ?end_child {
            get {
                return this.paned.end_child;
            }
            set {
                this.paned.end_child = value;
            }
        }

        public PanedPercentage(Gtk.Orientation orientation,
                               double          percentage)
        {
            this.set_layout_manager(new Gtk.BinLayout());
            this.paned = new Gtk.Paned(orientation);
            this.paned.set_parent(this);
            this.paned.hexpand = true;
            this.paned.vexpand = true;
            this.paned.halign = Gtk.Align.FILL;
            this.paned.valign = Gtk.Align.FILL;
            this.button_pressed = false;

            if (orientation == Gtk.Orientation.VERTICAL) {
                this.horizontal = true;
            } else {
                this.horizontal = false;
            }
            this.desired_paned_percentage = percentage;

            var controller = new Gtk.GestureClick();
            controller.propagation_phase = Gtk.PropagationPhase.CAPTURE;
            this.add_controller(controller);
            controller.pressed.connect(() => {
                this.button_pressed = true;
            });
            controller.released.connect(() => {
                this.button_pressed = false;
            });

            /*
             * This is a trick to ensure that the paned remains with the same relative
             * position, no mater if the user resizes the window
             */

            this.paned.notify.connect((pspec) => {
                switch (pspec.get_name()) {
                    case "max-position":
                        this.paned.position = (int) (((double) this.paned.max_position) * this.desired_paned_percentage);
                        break;

                    case "position":
                        if (this.button_pressed) {
                            this.desired_paned_percentage = ((double) this.paned.position) /
                                                            ((double) this.paned.max_position);
                        }
                        break;
                }
            });
        }
    }
}
