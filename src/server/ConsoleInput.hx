package server;

import js.html.Console;
import js.node.Readline;
import js.Node.process;
using StringTools;

class ConsoleInput {

	final main:Main;

	public function new(main:Main) {
		this.main = main;
	}

	public function initConsoleInput():Void {
		final rl = Readline.createInterface(process.stdin, process.stdout);
		haxe.Log.trace = (msg, ?pos) -> {
			Readline.clearLine(process.stdout, 0);
			Readline.cursorTo(process.stdout, 0, null);
			Console.log(msg);
			rl.prompt(true);
		};
		rl.prompt();
		rl.on("line", line -> {
			parseLine(line);
			rl.prompt();
		});
		// rl.on("close", exit);
	}

	function parseLine(line:String):Void {
		if (line.startsWith("/addAdmin")) {
			final args = line.split(" ");
			if (args.length != 3) {
				trace("Wrong count of arguments");
				return;
			}
			final name = args[1];
			final password = args[2];
			if (main.badNickName(name)) {
				final error = Lang.get("usernameError")
					.replace("$MAX", '${main.config.maxLoginLength}');
				trace(error);
				return;
			}
			main.addAdmin(name, password);

		} else if (line == "/exit") {
			main.exit();
			return;
		} else {
			trace('Unknown command "$line". List:
/addAdmin name password | Adds channel admin
/exit | Exit process');
		}
	}

}
