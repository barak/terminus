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

const GLib = imports.gi.GLib;
const Shell = imports.gi.Shell;
const Meta = imports.gi.Meta;
const Gio = imports.gi.Gio;
const Main = imports.ui.main;
const Mainloop = imports.mainloop;

const MyIface = '<node>\
    <interface name="com.rastersoft.terminus">\
        <method name="SwapGuake" />\
        <method name="DisableKeybind" />\
        <method name="DoPing" >\
            <arg name="n" direction="in" type="i"/>\
            <arg name="response" direction="out" type="i"/>\
        </method>\
    </interface>\
</node>';

const MyProxy = Gio.DBusProxy.makeProxyWrapper(MyIface);
const GioSSS = Gio.SettingsSchemaSource;

let terminusObject;

class TerminusClass {

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

		this._currentProcess = new LaunchSubprocess(0, "TERMINUS", "--uuid");
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
			this._launchProcessId = Mainloop.timeout_add(this._reloadTime, () => {
				this._launchProcessId = 0;
				this._launch_process();
			});
		});
	}

	/**
	 * Enables the extension
	 */
	enable() {
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
				this.terminusInstance.activate_action('swap_guake', null);
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
				window.focus(0);
				window.connect('position-changed', () => {
					this._set_window_position(window);
				});
				window.connect('size-changed', () => {
					this._set_window_position(window);
				});
			}
		});
	}

	_set_window_position(window) {
		let area = window.get_work_area_current_monitor();
		window.move_resize_frame(false, area.x, area.y, area.width, this._settings2.get_int("guake-height"));
	}

	disable() {
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


function init() {
	// delegate everything to the main program when running under X11
	terminusObject = new TerminusClass();
}

function enable() {
	terminusObject.enable();
}

function disable() {
	terminusObject.disable();
}

/**
 * This class encapsulates the code to launch a subprocess that can detect whether a window belongs to it
 * It only accepts to do it under Wayland, because under X11 there is no need to do these tricks
 *
 * It is compatible with https://gitlab.gnome.org/GNOME/mutter/merge_requests/754 to simplify the code
 *
 * @param {int}    flags         Flags for the SubprocessLauncher class
 * @param {string} process_id    An string id for the debug output
 * @param {string} cmd_parameter A command line parameter to pass when running. It will be passed only under Wayland,
 *                               so, if this parameter isn't passed, the app can assume that it is running under X11.
 */
var LaunchSubprocess = class {

	constructor(flags, process_id, cmd_parameter) {
		this._process_id = process_id;
		this._cmd_parameter = cmd_parameter;
		this._UUID = null;
		this._flags = flags | Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE;
		this._flags |= Gio.SubprocessFlags.STDIN_PIPE;
		this._launcher = new Gio.SubprocessLauncher({ flags: this._flags });
		this.subprocess = null;
		this.process_running = false;
	}

	spawnv(argv) {
		let UUID_string = null;
		/*
		 * Generate a random UUID to allow the extension to identify the window. It must be random
		 * to avoid other programs to cheat and pose themselves as the true process. This also means that
		 * launching the program from the command line won't give "superpowers" to it,
		 * but will work like any other program. Of course, under X11 it doesn't matter, but it does
		 * under Wayland.
		 */
		this._UUID = GLib.uuid_string_random();
		UUID_string = this._UUID + '\n';
		argv.push(this._cmd_parameter);
		this.subprocess = this._launcher.spawnv(argv);
		if (this.subprocess) {
			/*
			 * Send the UUID to the application using STDIN as a "secure channel". Sending it as a parameter
			 * would be insecure, because another program could read it and create a window before our process,
			 * and cheat the extension. This is done only in Wayland, because under X11 there is no need for it.
			 *
			 * It also reads STDOUT and STDERR and sends it to the journal using global.log(). This allows to
			 * have any error from the desktop app in the same journal than other extensions. Every line from
			 * the desktop program is prepended with the "process_id" parameter sent in the constructor.
			 */
			this.subprocess.communicate_utf8_async(UUID_string, null, (object, res) => {
				try {
					let [d, stdout, stderr] = object.communicate_utf8_finish(res);
					if (stdout.length != 0) {
						global.log(`${this._process_id}: ${stdout}`);
					}
				} catch (e) {
					global.log(`${this._process_id}_Error: ${e}`);
				}
			});
			this.subprocess.wait_async(null, () => {
				this.process_running = false;
			});
			this.process_running = true;
		}
		return this.subprocess;
	}

	set_cwd(cwd) {
		this._launcher.set_cwd(cwd);
	}

	/**
	 * Queries whether the passed window belongs to the launched subprocess or not.
	 * @param {MetaWindow} window The window to check.
	 */
	query_window_belongs_to(window) {
		if (this._UUID == null) {
			throw new Error("No process running");
		}
		if (!this.process_running) {
			throw new Error("No process running");
		}
		return (window.get_title() == this._UUID);
	}
}
