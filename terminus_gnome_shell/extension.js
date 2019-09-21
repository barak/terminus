
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
        this._settings = new Gio.Settings({schema: 'org.rastersoft.terminus.keybindings'});
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
                    this.terminusInstance = new MyProxy(Gio.DBus.session, 'com.rastersoft.terminus','/com/rastersoft/terminus');
                }
                this.terminusInstance.DisableKeybindRemote( (result, error) => {
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
            this._settings.set_strv("guake-mode-gnome-shell",new Array(new_key));
        }
    }
}


function init() {
    terminusObject = new TerminusClass();
}

function enable() {
    terminusObject.enable();
}

function disable() {
    terminusObject.disable();
}
