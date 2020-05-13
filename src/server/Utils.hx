package server;

import js.node.Https;
import js.node.Os;

class Utils {

	public static function getGlobalIp(callback:(ip:String)->Void):Void {
		// untyped to skip second null argument for node < v10
		Https.get(untyped "https://myexternalip.com/raw", r -> {
			r.setEncoding("utf8");
			final data = new StringBuf();
			r.on("data", chunk -> data.add(chunk));
			r.on("end", _ -> callback(data.toString()));
		}).on("error", e -> {
			trace("Warning: connection error, server is local.");
			callback("127.0.0.1");
		});
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
		for (i in 0...ids.length) {
			final n = ids[i];
			if (id < n) {
				ids.insert(i, id);
				return;
			}
		}
		ids.push(id);
	}

	public static function shuffle<T>(arr:Array<T>):Void {
		for (i in 0...arr.length) {
			final n = Std.random(arr.length);
			final a = arr[i];
			final b = arr[n];
			arr[i] = b;
			arr[n] = a;
		}
	}

}
