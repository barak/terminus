namespace Terminus {
	class Parameters : Object {
		public bool bind_keys;
		public bool launch_guake;
		public bool check_guake;
		public string[] command;

		public Parameters(string [] argv) {
			int  param_counter = 0;
			bool exit_at_end   = false;

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
                    print("Usage: terminus [--guake] [--check_guake] [--nobindkey] [-e command to launch and params]\n");
                    print("When using the '-e' parameter, it must be the last one.\n");
					exit_at_end = true;
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
					add_commands = true;
					continue;
				}
			}
			if (exit_at_end) {
				Posix.exit(0);
			}
		}
	}
}
