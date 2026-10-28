package server;

import haxe.DynamicAccess;
import js.lib.Error;
import js.node.Dns;
import js.node.Http;
import js.node.Https;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.node.url.URL;

class HttpProxy {
	static inline final MAX_CONNECTIONS = 32;
	static inline final MAX_REDIRECTS = 3;
	static inline final TIMEOUT_MS = 15000;

	static final REQUEST_HEADERS = [
		"range",
		"if-range",
		"if-modified-since",
		"if-none-match",
		"accept"
	];
	static final RESPONSE_HEADERS = [
		"content-length",
		"content-range",
		"accept-ranges",
		"content-encoding",
		"etag",
		"last-modified"
	];

	static final matchPrivateIpv4 = ~/^(0|10|127|169\.254|192\.168|172\.(1[6-9]|2\d|3[01])|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])|192\.0\.[02]|198\.(1[89]|51\.100)|203\.0\.113|2(2[4-9]|[34]\d|5[0-5]))(\.\d+){1,3}$/;
	static final matchPrivateIpv6 = ~/^((0+:){5}ffff:|fc|fd|fe[89ab]|ff|100::|2001:(db8|10|20):)[0-9a-f]*/i;
	static var activeRequests = 0;

	public static function isPrivateHost(host:String):Bool {
		var h = host.toLowerCase();
		if (h.startsWith("[") && h.endsWith("]")) {
			h = h.substring(1, h.length - 1);
		}
		if (h == "localhost" || h.endsWith(".localhost") || h.endsWith(".local")) {
			return true;
		}
		if (h.startsWith("::ffff:")) {
			h = h.substr(7);
			// WHATWG URL normalizes ::ffff:127.0.0.1 to ::ffff:7f00:1
			if (h.contains(":")) {
				final parts = h.split(":");
				if (parts.length == 2) {
					final hi = Std.parseInt("0x" + parts[0]) ?? 0;
					final lo = Std.parseInt("0x" + parts[1]) ?? 0;
					h = '${(hi >> 8) & 0xff}.${hi & 0xff}.${(lo >> 8) & 0xff}.${lo & 0xff}';
				}
			}
		}
		if (h.contains(":")) {
			return h == "::"
				|| h == "::1"
				|| ~/^[0:]+1?$/.match(h)
				|| h.startsWith("64:ff9b:")
				|| matchPrivateIpv6.match(h);
		}
		return matchPrivateIpv4.match(h);
	}

	static function parseTarget(req:IncomingMessage, reqUrl:URL):Null<String> {
		final prefix = "?url=";
		final i = req.url.indexOf(prefix);
		if (i < 0) return reqUrl.searchParams.get("url");
		final tail = req.url.substr(i + prefix.length);
		return tail.startsWith("http://")
			|| tail.startsWith("https://") ? tail : reqUrl.searchParams.get("url");
	}

	public static function proxyUrl(req:IncomingMessage, res:ServerResponse, reqUrl:URL):Void {
		final target = parseTarget(req, reqUrl);
		if (target == null) {
			HttpServer.sendText(res, 400, "Proxy error: bad request");
			return;
		}
		if (activeRequests >= MAX_CONNECTIONS) {
			HttpServer.sendText(res, 503, "Proxy error: too many requests");
			return;
		}
		activeRequests++;
		var closed = false;
		function release():Void {
			if (closed) return;
			closed = true;
			activeRequests--;
		}
		res.once("close", release);
		if (!proxyRequest(target, req, res, 0)) {
			release();
			HttpServer.sendText(res, 400, "Proxy error: bad request");
		}
	}

	static function proxyRequest(
		rawUrl:String,
		req:IncomingMessage,
		res:ServerResponse,
		redirects:Int
	):Bool {
		final url = try {
			new URL(rawUrl);
		} catch (e) {
			return false;
		}
		if (url.protocol != "http:" && url.protocol != "https:") return false;
		if (url.host == req.headers["host"]) return false;
		if (isPrivateHost(url.hostname)) return false;

		final headers:DynamicAccess<String> = {
			"user-agent": req.headers["user-agent"] ?? "Mozilla/5.0",
			"referer": url.href,
		};
		for (name in REQUEST_HEADERS) {
			final value:String = req.headers[name];
			if (value != null) headers[name] = value;
		}

		final host = url.hostname.startsWith("[")
			&& url.hostname.endsWith("]") ? url.hostname.substring(1, url.hostname.length
				- 1) : url.hostname;
		final options:Dynamic = {
			host: host,
			path: url.pathname + url.search,
			method: req.method,
			headers: headers,
			timeout: TIMEOUT_MS,
			lookup: safeLookup,
		};
		if (url.port != "") options.port = Std.parseInt(url.port);

		var redirected = false;
		final request = url.protocol == "https:" ? Https.request : Http.request;
		final proxy = request(options, (proxyRes:IncomingMessage) -> {
			final status = proxyRes.statusCode;
			final location:String = proxyRes.headers["location"];
			if (location != null
				&& (status == 301
					|| status == 302
					|| status == 303
					|| status == 307
					|| status == 308)) {
				redirected = true;
				proxyRes.resume();
				if (redirects >= MAX_REDIRECTS) {
					HttpServer.sendText(res, 502, "Proxy error: too many redirects");
					return;
				}
				final next = try new URL(location, url.href).href catch (e) null;
				if (next == null || !proxyRequest(next, req, res, redirects + 1)) {
					HttpServer.sendText(res, 502, "Proxy error: bad redirect");
				}
				return;
			}
			final outHeaders:DynamicAccess<String> = {
				"content-type": "application/octet-stream"
			};
			for (name in RESPONSE_HEADERS) {
				final value:String = proxyRes.headers[name];
				if (value != null) outHeaders[name] = value;
			}
			res.writeHead(status, outHeaders);
			if (req.method == "HEAD") {
				proxyRes.resume();
				res.end();
				return;
			}
			HttpServer.pipeline(proxyRes, res);
		});

		final onClose = () -> {
			if (!proxy.destroyed) proxy.destroy();
		};
		res.once("close", onClose);
		proxy.on("close", () -> res.removeListener("close", onClose));

		proxy.on("timeout", () -> proxy.destroy(new Error("timeout")));
		proxy.on("error", err -> {
			proxy.destroy();
			if (redirected) return;
			if (!res.headersSent) {
				HttpServer.sendText(res, 502, "Proxy error: request failed");
			} else if (!res.writableEnded) {
				res.destroy();
			}
		});
		proxy.end();
		return true;
	}

	public static function safeLookup(host:String, opts:Dynamic, cb:Dynamic):Void {
		Dns.lookup(host, opts, (err, addr:Dynamic, fam) -> {
			final list:Array<Dynamic> = Std.isOfType(addr, Array) ? addr : [{address: addr}];
			if (err == null && list.exists(a -> a.address != null && isPrivateHost(a.address))) {
				cb(new Error("blocked"), null, null);
				return;
			}
			cb(err, addr, fam);
		});
	}
}
