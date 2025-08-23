/*
 * Copyright 2025 (C) Raster Software Vigo (Sergio Costas)
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

using Vte;
using Gtk;
using Gdk;

using GLib;
using Posix;

namespace Terminus {
    public class Process {
        /* This class defines a process and their properties, along with their child processes */
        private int _pid;
        private int _ppid;
        private int _uid;
        private int _euid;
        private string _command_name;
        private Gee.LinkedList<weak Process> _childs;

        public int pid {
            get {
                return this._pid;
            }
        }

        public int ppid {
            get {
                return this._ppid;
            }
        }

        public string command_name {
            get {
                return this._command_name;
            }
        }

        // True if this, or any child process, is running as root
        public bool is_root {
            get {
                if (this._euid == 0) {
                    return true;
                }
                foreach (var child in this._childs) {
                    if (child.is_root) {
                        return true;
                    }
                }
                return false;
            }
        }

        public bool has_child {
            get {
                return (this._childs.size != 0);
            }
        }

        public string ?child_name {
            get {
                if (this._childs.size == 0) {
                    return null;
                }
                foreach (var child in this._childs) {
                    if (child.command_name == "sudo") {
                        return child.child_name ?? "sudo";
                    }
                }
                return this._childs[0].command_name;
            }
        }

        public Process(string pid)
        {
            this._pid = 0;
            this._ppid = 0;
            this._childs = new Gee.LinkedList<weak Process>();

            var statusFile = GLib.File.new_build_filename("/proc", pid, "status");
            if (statusFile.query_exists(null)) {
                var       is = statusFile.read(null);
                Bytes     data;
                ByteArray buffer = new ByteArray();
                while (true) {
                    data = is.read_bytes(10240, null);
                    if (data.get_size() == 0) {
                        break;
                    }
                    buffer.append(data.get_data());
                }
                buffer.append({ 0 }); // zero-ended string
                var lines = ((string) buffer.data).split("\n");
                foreach (var line in lines) {
                    if (line.has_prefix("Pid:")) {
                        this._pid = int.parse(line.substring(4));
                        continue;
                    }
                    if (line.has_prefix("PPid:")) {
                        this._ppid = int.parse(line.substring(5));
                        continue;
                    }
                    if (line.has_prefix("Uid:")) {
                        var uid_data = line.split("\t");
                        this._uid = int.parse(uid_data[1]);
                        this._euid = int.parse(uid_data[2]);
                        continue;
                    }
                    if (line.has_prefix("Name:")) {
                        this._command_name = line.substring(5).strip();
                        continue;
                    }
                }
            }
        }

        public void
        add_child(Process child)
        {
            this._childs.add(child);
        }
    }

    public class Processes {
        /* Contains a tree with the processes pids and their childs, along with their properties,
         * to easily know if a terminal has a running child and if it is a root one.
         */

        private Gee.HashMap<int, Process> process_map;

        public Processes()
        {
            this.update_tree();
            // refresh the process tree twice per second
            GLib.Timeout.add(500, () => {
                this.update_tree();
                return true;
            });
        }

        private void
        update_tree()
        {
            this.process_map = new Gee.HashMap<int, Process>();

            var      procdir = GLib.File.new_for_path("/proc");
            var      enumerator = procdir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
            FileInfo info = null;
            while ((info = enumerator.next_file(null)) != null) {
                if (info.get_file_type() != FileType.DIRECTORY) {
                    continue;
                }
                var process = new Terminus.Process(info.get_name());
                if (process.pid == 0) {
                    continue;
                }
                this.process_map.set(process.pid, process);
            }

            foreach (var process in this.process_map) {
                var ppid = process.value.ppid;
                if (this.process_map.has_key(ppid)) {
                    this.process_map.get(ppid).add_child(process.value);
                }
            }
        }

        public string ?
        get_child_name(int pid)
        {
            if (!this.process_map.has_key(pid)) {
                return null;
            }
            var process = this.process_map.get(pid);
            return process.child_name;
        }

        public bool
        has_root_child(int pid)
        {
            if (!this.process_map.has_key(pid)) {
                return false; // just in case
            }
            var process = this.process_map.get(pid);
            return process.is_root;
        }

        public bool
        has_running_child(int pid)
        {
            if (!this.process_map.has_key(pid)) {
                return false; // just in case
            }
            var process = this.process_map.get(pid);
            return process.has_child;
        }
    }
}
