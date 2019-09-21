
const Main = imports.ui.main;
const Shell = imports.gi.Shell;
const Meta = imports.gi.Meta;
const Gio = imports.gi.Gio;
const Lang = imports.lang;
const ExtensionUtils = imports.misc.extensionUtils;

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
var terminusObject;

class TerminusClass {

	constructor() {
		this._settings = new Gio.Settings({ schema: 'org.rastersoft.terminus.keybindings' });
		this._settingsChanged(null, "guake-mode"); // copy the guake-mode key to guake-mode-gnome-shell key
		this.terminusInstance = null;
	}

	enable() {
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
					this.terminusInstance = new MyProxy(Gio.DBus.session, 'com.rastersoft.terminus', '/com/rastersoft/terminus');
				}
				this.terminusInstance.DisableKeybindRemote((result, error) => {
					this.terminusInstance.SwapGuakeSync();
				});
			}
		);
	}

	disable() {
		if (this._settingsChangedConnect) {
			this._settings.disconnect(this._settingsChangedConnect);
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
	if (Meta.is_wayland_compositor())
		terminusObject = new TerminusClass();
}

function enable() {
	if (Meta.is_wayland_compositor())
		terminusObject.enable();
}

function disable() {
	if (Meta.is_wayland_compositor()) {
		terminusObject.disable();
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
 * @param {string} cmd_parameter A command line parameter to pass when running. It will be passed only under Wayland,
 *                          so, if this parameter isn't passed, the app can assume that it is running under X11.
 */
var LaunchSubprocess = class {

	constructor(flags, process_id, cmd_parameter) {
		this._process_id = process_id;
		this._cmd_parameter = cmd_parameter;
		this._UUID = null;
		this._flags = flags | Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE;
		if (Meta.is_wayland_compositor()) {
			this._flags |= Gio.SubprocessFlags.STDIN_PIPE;
		}
		this._launcher = new Gio.SubprocessLauncher({ flags: this._flags });
		this.subprocess = null;
		this.process_running = false;
	}

	spawnv(argv) {
		let UUID_string = null;
		if (Meta.is_wayland_compositor()) {
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
		}
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
		if (!Meta.is_wayland_compositor()) {
			throw new Error("Not in wayland");
		}
		if (this._UUID == null) {
			throw new Error("No process running");
		}
		if (!this.process_running) {
			throw new Error("No process running");
		}
		return (window.get_title() == this._UUID);
	}
}
