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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

//using GIO
//using GIO-unix

namespace Terminus {
	class Parameters : Object {
		public bool bind_keys = true;
		public bool help = false;
		public bool version = false;
		public bool no_window = false;
		public bool check_guake = false;
		public bool read_uuid = false;
		public string[] command = {};
		public string ? working_directory;

		public Parameters() {
			this.working_directory = GLib.Environment.get_home_dir();
		}

		public bool parse_argv(string [] argv) {
			int param_counter = 0;
			var add_commands = false;

			while (param_counter < (argv.length - 1)) {
				param_counter++;
				bool is_last_command = (param_counter == (argv.length - 1));
				var parameter = argv[param_counter];
				if (add_commands) {
					this.command += parameter;
					continue;
				}
				if ((parameter == "--check-guake") ||
				    (parameter == "--check_guake")) {
						this.check_guake = true;
						continue;
				}
				if ((parameter == "--check_guake_wayland") || (parameter == "--check_guake_x11")) {
					this.check_guake = true;
					this.no_window = true;
					this.bind_keys = false;
					continue;
				}
				if ((parameter == "-v") || (parameter == "--version")) {
					this.version = true;
					continue;
				}
				if ((parameter == "-h") || (parameter == "--help")) {
					this.help = true;
					continue;
				}
				if (parameter == "--no-window") {
					this.no_window = true;
					continue;
				}
				if (parameter == "--uuid") {
					this.read_uuid = true;
					continue;
				}
				if (parameter == "--nobindkey") {
					this.bind_keys = false;
					continue;
				}
				if ((parameter == "-e") || (parameter == "--command")) {
					if (is_last_command) {
						this.required_command(parameter);
						return false;
					}
					this.command = {};
					param_counter++;
					this.command += argv[param_counter];
					continue;
				}
				if (parameter.has_prefix("--command=")) {
					this.command  = {};
					this.command += parameter.substring(10);
					continue;
				}
				if ((parameter == "-x") || (parameter == "--execute") || (parameter == "--")) {
					if (is_last_command) {
						this.required_command(parameter);
						return false;
					}
					this.command = {};
					add_commands = true;
					continue;
				}
				if (parameter == "--working-directory") {
					if (is_last_command) {
						this.required_path(parameter);
					}
					param_counter++;
					this.working_directory = argv[param_counter];
					continue;
				}
				if (parameter.has_prefix("--working-directory=")) {
					this.working_directory = parameter.substring(20);
					continue;
				}
				print(_("Parameter '%s' unknown.\n\n").printf(parameter));
				return false;
			}
			return true;
		}

		private void required_path(string parameter) {
			print(_("The '%s' parameter requires a path after it.\n\n").printf(parameter));
			Terminus.show_usage();
			Posix.exit(-1);
		}

		private void required_command(string parameter) {
			print(_("The '%s' parameter requires a command after it.\n\n").printf(parameter));
			Terminus.show_usage();
			Posix.exit(-1);
		}

	}
	void show_usage() {
		print(_("""Usage:
terminus [OPTION...] [-- COMMAND ...]

Help commands:
-h, --help                    show this help
-v, --version                 show version

Options:
-x, --execute, --             launches a new Terminus window and execute the remainder of the command line inside the terminal
-e, --command=STRING          launches a new Terminus window and execute the argument inside the terminal
--working-directory=DIRNAME   sets the terminal directory to DIRNAME
--no-window                   launch Terminus but don't open a window
--nobindkey                   don't try to bind the Quake-mode key (useful for gnome shell)
--check-gnome                 exit if we are running it in Gnome Shell (guake mode should be managed by the extension)
"""));
	}

}
