/*
 * Copyright 2016-2019 (C) Raster Software Vigo (Sergio Costas)
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

import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class TerminusClass {

	constructor() {
		this._enabled = false;
		this._settings = new Gio.Settings({ schema: 'org.rastersoft.terminus.keybindings' });
		this._settings2 = new Gio.Settings({ schema: 'org.rastersoft.terminus' });
		this._settingsChanged("guake-mode"); // copy the guake-mode key to guake-mode-gnome-shell key
		this.terminusInstance = null;
		this._shown_error = false;
		this._currentProcess = null;
	}

	_launch_process() {
		if (this._currentProcess !== null) {
			return;
		}
		let argv = [];
		argv.push("terminus");
		argv.push("--no-window");
		argv.push("--nobindkey");

		this._currentProcess = new LaunchSubprocess(0, "TERMINUS");
		this._currentProcess.spawnv(argv);
		this._currentProcess.subprocess.wait_async(null, () => {
			this._reloadTime = 1000;
			if (this._currentProcess.subprocess.get_if_exited()) {
				let retVal = this._currentProcess.subprocess.get_exit_status();
				if (retVal == 1) {
					if (!this._shown_error) {
						// show it only once
						Main.notify("Can't launch Terminus", "There is already an instance of Terminus running. You must kill all of them to allow Terminus guake mode to work.");
					}
					this._shown_error = true;
					this._reloadTime = 1000;
				} else {
					this._shown_error = false;
				}
			} else {
				this._shown_error = false;
			}
			this._desktopWindow = null;
			this._currentProcess = null;
			if (this._launchDesktopId) {
				GLib.source_remove(this._launchDesktopId);
			}
			if (this._enabled === false) {
				return;
			}
			this._launchProcessId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, this._reloadTime, () => {
				this._launchProcessId = 0;
				this._launch_process();
			});
		});
	}

	/**
	 * Enables the extension
	 */
	enable() {
		if (this._enabled) {
			return;
		}
		// If the desktop is still starting up, we wait until it is ready
		if (Main.layoutManager._startingUp) {
			this._startupPreparedId = Main.layoutManager.connect('startup-complete', () => {
				this._innerEnable();
			});
		} else {
			this._innerEnable();
		}
	}

	_innerEnable() {
		this._enabled = true;
		this._launch_process();
		if (this._startupPreparedId) {
			Main.layoutManager.disconnect(this._startupPreparedId);
			this._startupPreparedId = null;
		}
		this._settingsChangedConnect = this._settings.connect('changed', (st, name) => {
			this._settingsChanged(name);
		});
		let mode = Shell.ActionMode ? Shell.ActionMode.NORMAL : Shell.KeyBindingMode.ALL;
		let flags = Meta.KeyBindingFlags.NONE;
		Main.wm.addKeybinding(
			"guake-mode-gnome-shell",
			this._settings,
			flags,
			mode,
			() => {
				if (this.terminusInstance === null) {
					this.terminusInstance = Gio.DBusActionGroup.get(
						Gio.DBus.session,
						'com.rastersoft.terminus',
						'/com/rastersoft/terminus'
					);
				}
				this.terminusInstance.activate_action('swap-guake', null);
			}
		);
		this._idMap = global.window_manager.connect_after('map', (obj, windowActor) => {
			if (!this._currentProcess) {
				return false;
			}
			let window = windowActor.get_meta_window();
			let belongs;
			try {
				belongs = this._currentProcess.query_window_belongs_to(window);
			} catch (err) {
				belongs = false;
			}
			if (belongs) {
				// This is the Guake Terminal window, so ensure that it is kept above and shown in all workspaces
				window.make_above();
				window.stick();
				this._set_window_position(window);
				this._set_window_size(window);
				window.focus(0);
				window.connect('position-changed', () => {
					this._set_window_position(window);
				});
				window.connect('size-changed', () => {
					this._set_window_size(window);
				});
			}
		});
	}

	_set_window_position(window) {
		let area = window.get_work_area_current_monitor();
		window.move_frame(false, area.x, area.y);
	}

	_set_window_size(window) {
		let area = window.get_work_area_current_monitor();
		let rectangle = window.get_frame_rect();
		let margin = 48;
		if (rectangle.height >= (area.height - margin)) {
			window.move_resize_frame(true, area.x, area.y, area.width, area.height - margin);
		}
	}

	disable() {
		if (!this._enabled) {
			return;
		}
		this._enabled = false;
		if (this._settingsChangedConnect) {
			this._settings.disconnect(this._settingsChangedConnect);
		}
		if (this._idMap) {
			global.window_manager.disconnect(this._idMap);
		}
		Main.wm.removeKeybinding("guake-mode-gnome-shell");
	}

	_settingsChanged(name) {
		if (name == "guake-mode") {
			var new_key = this._settings.get_string("guake-mode");
			this._settings.set_strv("guake-mode-gnome-shell", new Array(new_key));
		}
	}
}


/**
 * This class encapsulates the code to launch a subprocess that can detect whether a window belongs to it
 * It only accepts to do it under Wayland, because under X11 there is no need to do these tricks
 *
 * It is compatible with https://gitlab.gnome.org/GNOME/mutter/merge_requests/754 to simplify the code
 *
 * @param {int} flags Flags for the SubprocessLauncher class
 * @param {string} process_id An string id for the debug output
 */
class LaunchSubprocess {
	constructor(flags, process_id) {
		this._process_id = process_id;
		this.cancellable = new Gio.Cancellable();
		this._launcher = new Gio.SubprocessLauncher({ flags: flags | Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE });
		if (Meta.is_wayland_compositor()) {
			try {
				this._waylandClient = Meta.WaylandClient.new(this._launcher);
			} catch (e) {
				this._waylandClient = Meta.WaylandClient.new(global.context, this._launcher);
			}
		}
		this.subprocess = null;
		this.process_running = false;
	}

	spawnv(argv) {
		try {
			if (Meta.is_wayland_compositor()) {
				this.subprocess = this._waylandClient.spawnv(global.display, argv);
			} else {
				this.subprocess = this._launcher.spawnv(argv);
			}
		} catch (e) {
			this.subprocess = null;
			console.log(`Error while trying to launch TERMINUS process: ${e.message}\n${e.stack}`);
		}
		// This is for GLib 2.68 or greater
		if (this._launcher.close) {
			this._launcher.close();
		}
		this._launcher = null;
		if (this.subprocess) {
			/*
			     * It reads STDOUT and STDERR and sends it to the journal using console.log(). This allows to
			     * have any error from the desktop app in the same journal than other extensions. Every line from
			     * the desktop program is prepended with the "process_id" parameter sent in the constructor.
			     */
			this._dataInputStream = Gio.DataInputStream.new(this.subprocess.get_stdout_pipe());
			this.read_output();
			this.subprocess.wait_async(this.cancellable, () => {
				this.process_running = false;
				this._dataInputStream = null;
				this.cancellable = null;
			});
			this.process_running = true;
		}
		return this.subprocess;
	}

	set_cwd(cwd) {
		this._launcher.set_cwd(cwd);
	}

	read_output() {
		if (!this._dataInputStream) {
			return;
		}
		this._dataInputStream.read_line_async(GLib.PRIORITY_DEFAULT, this.cancellable, (object, res) => {
			try {
				const [output, length] = object.read_line_finish_utf8(res);
				if (length) {
					print(`${this._process_id}: ${output}`);
				}
			} catch (e) {
				if (e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED)) {
					return;
				}
				console.error(e, `${this._process_id}_Error`);
			}

			this.read_output();
		});
	}

	/**
	 * Queries whether the passed window belongs to the launched subprocess or not.
	 *
	 * @param {MetaWindow} window The window to check.
	 */
	query_window_belongs_to(window) {
		if (!this.process_running) {
			return false;
		}

		if (Meta.is_wayland_compositor()) {
			return this._waylandClient.owns_window(window);
		}

		try {
			const pid = parseInt(this.subprocess.get_identifier());
			const appid = window.get_gtk_application_id();
			return ((pid === window.get_pid()) && (appid == 'com.rastersoft.terminus'));
		} catch(e) {
			return false;
		}
	}
};