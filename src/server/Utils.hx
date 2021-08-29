package server;

import js.node.Http;
import js.node.Https;
import js.node.Os;
import js.node.url.URL;
import sys.FileSystem;

class Utils {
	public static function ensureDir(path:String):Void {
		if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
	}

	public static function isPortFree(port:Int, callback:(isFree:Bool) -> Void):Void {
		final server = Http.createServer();
		final timeout = 1000;
		var status = false;

		server.setTimeout(timeout);
		server.once("error", function(err) {
			status = false;
			server.close();
		});
		server.once("timeout", function() {
			status = false;
			trace('Timeout (${timeout}ms) occurred waiting for port $port to be available');
			server.close();
		});
		server.once("listening", function() {
			status = true;
			server.close();
		});
		server.once("close", () -> callback(status));
		server.listen(port);
	}

	public static function getGlobalIp(callback:(ip:String) -> Void):Void {
		function onError(e):Void {
			trace("Warning: connection error, server is local.");
			callback("127.0.0.1");
		}
		final url = new URL("https://myexternalip.com/raw");
		Https.get({ // this overload for node < v10.9.0
			timeout: 5000,
			protocol: url.protocol,
			host: url.host,
			path: url.pathname
		}, r -> {
			r.setEncoding("utf8");
			final data = new StringBuf();
			r.on("data", chunk -> data.add(chunk));
			r.on("end", _ -> callback(data.toString()));
		}).on("error", onError).on("timeout", onError);
	}

	public static function getLocalIp():String {
		final ifaces = Os.networkInterfaces();
		for (field in Reflect.fields(ifaces)) {
			final type = Reflect.field(ifaces, field);

			for (ifname in Reflect.fields(type)) {
				final iface = Reflect.field(type, ifname);
				// skip over internal (i.e. 127.0.0.1) and non-ipv4 addresses
				if ('IPv4' != iface.family || iface.internal != false) continue;
				// this interface has only one ipv4 address
				return iface.address;
			}
		}
		return "127.0.0.1";
	}

	public static function isOutOfRange(value:Float, min:Float, max:Float):Bool {
		return value == null || Math.isNaN(value) || value < min || value > max;
	}

	public static function sortedPush(ids:Array<Int>, id:Int):Void {
		for (i => n in ids) {
			if (id < n) {
				ids.insert(i, id);
				return;
			}
		}
		ids.push(id);
	}

	public static function shuffle<T>(arr:Array<T>):Void {
		for (i => a in arr) {
			final n = Std.random(arr.length);
			final b = arr[n];
			arr[i] = b;
			arr[n] = a;
		}
	}
}
