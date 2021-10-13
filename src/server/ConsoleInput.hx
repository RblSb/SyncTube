package server;

import haxe.Json;
import haxe.extern.EitherType as Or;
import haxe.io.Path;
import js.Node.process;
import js.html.Console;
import js.node.Readline;
import sys.FileSystem;
import sys.io.File;

using StringTools;

private typedef CommandData = {
	args:Array<String>,
	desc:String
}

private enum abstract Command(String) from String {
	var AddAdmin = "addAdmin";
	var RemoveAdmin = "removeAdmin";
	var Replay = "replay";
	var LogList = "logList";
	var Exit = "exit";
}

class ConsoleInput {
	final main:Main;
	final commands:Map<Command, CommandData> = [
		AddAdmin => {
			args: ["name", "password"],
			desc: "Adds channel admin"
		},
		RemoveAdmin => {
			args: ["name"],
			desc: "Removes channel admin"
		},
		Replay => {
			args: ["name"],
			desc: "Replay log file on server from user/logs/"
		},
		LogList => {
			args: [],
			desc: "Show log list from user/logs/"
		},
		Exit => {
			args: [],
			desc: "Exit process"
		}
	];

	public function new(main:Main) {
		this.main = main;
	}

	public function initConsoleInput():Void {
		final rl = Readline.createInterface({
			input: process.stdin,
			output: process.stdout,
			completer: onCompletion
		});
		haxe.Log.trace = (msg:Dynamic, ?infos:haxe.PosInfos) -> {
			Readline.clearLine(process.stdout, 0);
			Readline.cursorTo(process.stdout, 0, null);
			Console.log(formatOutput(msg, infos));
			rl.prompt(true);
		};
		rl.prompt();
		rl.on("line", line -> {
			parseLine(line);
			rl.prompt();
		});
		// rl.on("close", exit);
	}

	function formatOutput(v:Dynamic, infos:haxe.PosInfos):String {
		var str = Std.string(v);
		if (infos == null) return str;
		if (infos.customParams != null) {
			for (v in infos.customParams)
				str += ", " + Std.string(v);
		}
		return str;
	}

	function onCompletion(line:String):Array<Or<Array<String>, String>> {
		final commands:Array<String> = [
			for (item in commands.keys()) '/$item '
		];
		final matches = commands.filter(item -> item.startsWith(line));
		if (matches.length > 0) return [matches, line];
		return [commands, line];
	}

	function parseLine(line:String):Void {
		if (line.fastCodeAt(0) != "/".code || line.length < 2) {
			printHelp(line);
			return;
		}
		final args = line.trim().split(" ");
		final command:Command = args.shift().substr(1);
		if (commands[command] == null) {
			printHelp(line);
			return;
		}
		if (!isValidArgs(command, args)) return;

		switch (command) {
			case AddAdmin:
				final name = args[0];
				final password = args[1];
				if (main.badNickName(name)) {
					final error = Lang.get("usernameError")
						.replace("$MAX", '${main.config.maxLoginLength}');
					trace(error);
					return;
				}
				main.addAdmin(name, password);

			case RemoveAdmin:
				final name = args[0];
				main.removeAdmin(name);

			case Replay:
				Utils.ensureDir(main.logsDir);
				final name = args[0];
				final path = Path.normalize('${main.logsDir}/$name.json');
				if (!FileSystem.exists(path)) {
					trace('File "$path" not found');
					return;
				}
				final text = File.getContent(path);
				final events:Array<ServerEvent> = Json.parse(text);
				main.replayLog(events);

			case LogList:
				Utils.ensureDir(main.logsDir);
				final names = FileSystem.readDirectory(main.logsDir).filter(s -> {
					return s.endsWith(".json");
				});
				for (name in names) {
					trace(Path.withoutExtension(name));
				}

			case Exit:
				main.exit();
		}
	}

	function isValidArgs(command:Command, args:Array<String>):Bool {
		final len = args.length;
		final actual = commands[command].args.length;
		if (len != actual) {
			trace('Wrong count of arguments for command "$command" ($len instead of $actual)');
			return false;
		}
		return true;
	}

	function printHelp(line:String):Void {
		var maxLength = 0;
		for (name => data in commands) {
			final len = '/$name ${data.args.join(" ")}'.length;
			if (maxLength < len) maxLength = len;
		}
		final list:Array<String> = [];
		for (name => data in commands) {
			final args = data.args.join(" ");
			final item = '/$name $args'.rpad(" ", maxLength);
			list.push('$item | ${data.desc}');
		}
		final desc = list.join("\n");
		trace('Unknown command "$line". List:\n$desc');
	}
}
