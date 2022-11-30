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

    public interface DnDDestination : Object {
        public abstract void drop_terminal(Terminal terminal);
    }

    public class VoidDnDDestination : Object, DnDDestination {
        public void drop_terminal(Terminal terminal) {}
    }

    class DnDManager: Object {
        private Terminus.Terminal? origin;
        private DnDDestination? destination;

        public DnDManager() {
            this.reset();
        }

        private void reset() {
            this.destination = null;
            this.origin = null;
        }

        public void set_origin(Terminal origin) {
            this.origin = origin;
        }

        public void set_destination(DnDDestination destination) {
            this.destination = destination;
        }

        public bool is_origin(Vte.Terminal ?terminal) {
            return this.origin.compare_terminal(terminal);
        }

        public void do_drop() {
            if (this.destination != null) {
                // drop inside another terminal
                this.destination.drop_terminal(this.origin);
            } else {
                // drop outside, in a new window
                this.origin.extract_from_container();
                main_root.create_window(false, null, null, this.origin);
            }
            this.reset();
        }
    }
}
