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
        public abstract void
        drop_terminal(Terminal terminal);
        public abstract bool
        accepts_drop(Terminal terminal);
    }

    public class VoidDnDDestination : Object, DnDDestination {
        public void
        drop_terminal(Terminal terminal)
        {}
        public bool
        accepts_drop(Terminal terminal)
        {
            return false;
        }
    }

    class DnDManager : Object {
        private Terminus.Terminal?origin;
        private DnDDestination?destination;
        private bool _doing_dnd;
        private Gtk.TargetList _targets;

        public bool doing_dnd {
            get {
                return this._doing_dnd;
            }
        }

        public Gtk.TargetList targets {
            get {
                return this._targets;
            }
        }

        public signal void
        dnd_status();

        public DnDManager()
        {
            this._targets = new Gtk.TargetList(null);
            this._targets.add(Gdk.Atom.intern("terminusterminal", false), Gtk.TargetFlags.SAME_APP, 0);
            this._doing_dnd = false;
            this.reset();
        }

        private void
        reset()
        {
            this.destination = null;
            this.origin = null;
        }

        public void
        begin_dnd()
        {
            this._doing_dnd = true;
            this.dnd_status();
        }

        public void
        set_origin(Terminal origin)
        {
            this.origin = origin;
        }

        public void
        set_destination(DnDDestination destination)
        {
            this.destination = destination;
        }

        public bool
        is_origin(Vte.Terminal ?terminal)
        {
            return this.origin.compare_terminal(terminal);
        }

        public void
        do_drop()
        {
            if (this.destination != null) {
                // drop inside another terminal
                this.origin.drop_into(this.destination);
            } else {
                // drop outside, in a new window
                this.origin.extract_from_container();
                main_root.create_window(false, null, null, this.origin);
            }
            this._doing_dnd = false;
            this.dnd_status();
            this.reset();
        }
    }
}
