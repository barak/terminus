namespace Terminus {
	class Parameters : Object {
		public bool bind_keys;
		public bool launch_guake;
		public bool check_guake;
		public string[] command;

		public Parameters(string [] argv) {
			int param_counter = 0;

			this.bind_keys    = true;
			this.launch_guake = false;
			this.check_guake  = false;
			this.command      = {};

			var add_commands = false;

			while (param_counter < (argv.length - 1)) {
				param_counter++;
				if (add_commands) {
					this.command += argv[param_counter];
					continue;
				}
				if ((argv[param_counter] == "-h") || (argv[param_counter] == "--help")) {
					this.show_usage(0);
					break;
				}
				if (argv[param_counter] == "--guake") {
					this.launch_guake = true;
					continue;
				}
				if (argv[param_counter] == "--check_guake") {
					this.check_guake = true;
					continue;
				}
				if (argv[param_counter] == "--nobindkey") {
					this.bind_keys = false;
					continue;
				}
				if (argv[param_counter] == "-e") {
					param_counter++;
					if (param_counter == argv.length) {
						print(_("The -e param requires a command after it\n"));
						this.show_usage(-1);
					}
					this.command  = {};
					this.command += argv[param_counter];
					continue;
				}
				if (argv[param_counter] == "-x") {
					this.command = {};
					add_commands = true;
					continue;
				}
			}
		}

		private void show_usage(int retval) {
			print(_("""Usage: terminus [--guake] [--check_guake] [--nobindkey] [-e single command to launch] [-x command to launch and params]
When using the '-x' parameter, it must be the last one.
"""));
			Posix.exit(retval);
		}
	}
}
