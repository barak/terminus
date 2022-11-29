/*
 * Copyright 2022 (C) Raster Software Vigo (Sergio Costas)
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

using GLib;
using Vte;

namespace Terminus {
    class DnDManager: Object {
        private Terminus.Terminal? origin;
        private Terminus.Container? originContainer;
        private Terminus.Terminal? destination;

        public DnDManager() {
            this.destination = null;
            this.origin = null;
        }

        public void set_origin(Terminal origin, Container container) {
            this.origin = origin;
            this.originContainer = container;
        }

        public void set_destination(Terminal destination) {
            this.destination = destination;
        }

        public bool is_origin(Vte.Terminal ?terminal) {
            return this.origin.compare_terminal(terminal);
        }

        public void do_drop() {
            if (this.destination != null) {
                // drop inside another terminal
                this.originContainer.extract_current_terminal();
                this.destination.drop_terminal(this.origin);
            } else {
                // drop outside, in a new window
                this.originContainer.extract_current_terminal();
                main_root.create_window(false, null, null, this.origin);
            }
            this.origin = null;
            this.destination = null;
        }
    }
}
