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
				bool is_last_command = (param_counter == (argv.length - 1));
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
				if ((argv[param_counter] == "-e") || (argv[param_counter] == "--command")) {
					if (is_last_command) {
						print(_("The '%s' parameter requires a command after it.\n\n").printf(argv[param_counter]));
						this.show_usage(-1);
					}
					this.command = {};
					param_counter++;
					this.command += argv[param_counter];
					continue;
				}
				if (argv[param_counter].has_prefix("--command=")) {
					this.command  = {};
					this.command += argv[param_counter].substring(10);
					continue;
				}
				if ((argv[param_counter] == "-x") || (argv[param_counter] == "--execute") || (argv[param_counter] == "--")) {
					if (param_counter == (argv.length - 1)) {
						print(_("The '%s' parameter requires a command after it.\n\n").printf(argv[param_counter]));
						this.show_usage(-1);
					}
					this.command = {};
					add_commands = true;
					continue;
				}
			}
		}

		private void show_usage(int retval) {
			print(_("""Usage:
  terminus [OPTION...] [-- COMMAND ...]

Help commands:
  -h, --help            show this help

Options:
  -x, --execute, --     launches a new Terminus window and run the following parameter as a command inside, passing to it all the following parameters
  -e, --command         launches a new Terminos window and run the following parameter as a command inside
  --guake               launch Terminus in background
  --check_guake         launch Terminus in background and return if there is already another Terminus process
  --nobindkey           don't try to bind the Quake-mode key (useful for gnome shell)

"""));
			Posix.exit(retval);
		}
	}
}
