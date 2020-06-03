package server;

import haxe.io.Path;
import sys.io.File;
import haxe.Json;
import sys.FileSystem;
using StringTools;
using Lambda;

class Logger {

	final folder:String;
	final maxCount:Int;
	final verbose:Bool;
	final logs:Array<ServerEvent> = [];
	final matchFileFormat = ~/[0-9_-]+\.json$/;

	public function new(folder:String, maxCount:Int, verbose:Bool):Void {
		this.folder = folder;
		this.maxCount = maxCount;
		this.verbose = verbose;
	}

	public function log(event:ServerEvent):Void {
		logs.push(event);
		if (logs.length > 5000) logs.shift();
	}

	public function saveLog():Void {
		if (logs.length == 0) return;
		Utils.ensureDir(folder);
		removeOldestLog(folder);
		final name = DateTools.format(Date.now(), "%Y-%m-%d_%H_%M_%S");
		File.saveContent('$folder/$name.json', Json.stringify(logs, filterNulls, "\t"));
	}

	function filterNulls(key:Any, value:Any):Any {
		#if js
		if (value == null) return js.Lib.undefined;
		#end
		return value;
	}

	function removeOldestLog(folder:String):Void {
		final names = FileSystem.readDirectory(folder);
		if (names.count(item -> matchFileFormat.match(item)) < maxCount) return;
		var minDate = 0.0;
		var fileName:String = null;
		for (name in names) {
			final date = extractFileDate(name).getTime();
			if (minDate == 0 || minDate > date) {
				minDate = date;
				fileName = name;
			}
		}
		if (fileName == null) return;
		FileSystem.deleteFile('$folder/$fileName');
	}

	function extractFileDate(name:String):Date {
		name = Path.withoutExtension(name);
		final t = name.split("_");
		final d = t.shift().split("-");
		if (d.length != 3 && t.length != 3) return Date.fromTime(0);
		final s = '${d[0]}-${d[1]}-${d[2]} ${t[0]}:${t[1]}:${t[2]}';
		return Date.fromString(s);
	}

}
