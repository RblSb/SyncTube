package server;

import js.node.Http;
import js.node.Os;

class Utils {

	public static function getGlobalIp(callback:(ip:String)->Void):Void {
		Http.get("http://myexternalip.com/raw", r -> {
			r.setEncoding("utf8");
			r.on("data", callback);
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
				// this interface has only one ipv4 adress
				return iface.address;
			}
		}
		return "127.0.0.1";
	}
}
