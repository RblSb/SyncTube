package server;

import js.node.url.URL;
import js.node.Https;
import js.node.Os;
import sys.FileSystem;

class Utils {

	public static function ensureDir(path:String):Void {
		if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
	}

	public static function getGlobalIp(callback:(ip:String)->Void):Void {
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
		}).on("error", onError)
			.on("timeout", onError);
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
