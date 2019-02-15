/*
 * Copyright 2016 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Terminus
 *
 * Terminus is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
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

	public class PanedPercentage : Gtk.Paned {
		private int current_paned_position;
		private int current_paned_size;
		private double desired_paned_percentage;
		private bool changed_paned_size;
		private bool horizontal;

		public PanedPercentage(Gtk.Orientation orientation, double percentage) {
			this.current_paned_position = -1;
			this.current_paned_size     = -1;
			this.changed_paned_size     = false;

			this.orientation = orientation;
			if (orientation == Gtk.Orientation.VERTICAL) {
				this.horizontal = true;
			} else {
				this.horizontal = false;
			}
			this.desired_paned_percentage = percentage;

			/*
			 * This is a trick to ensure that the paned remains with the same relative
			 * position, no mater if the user resizes the window
			 */

			this.size_allocate.connect_after((allocation) => {
				if (this.horizontal) {
				    if (this.current_paned_size != allocation.height) {
				        this.current_paned_size = allocation.height;
				        this.changed_paned_size = true;
					}
				} else {
				    if (this.current_paned_size != allocation.width) {
				        this.current_paned_size = allocation.width;
				        this.changed_paned_size = true;
					}
				}
			});

			this.draw.connect((cr) => {
				if (changed_paned_size) {
				    this.current_paned_position = (int) (this.current_paned_size * this.desired_paned_percentage);
				    this.set_position(this.current_paned_position);
				    this.changed_paned_size = false;
				} else {
				    if (this.position != this.current_paned_position) {
				        this.current_paned_position   = this.position;
				        this.desired_paned_percentage = ((double) this.current_paned_position) / ((double) this.current_paned_size);
					}
				}
				return false;
			});
		}
	}
}
