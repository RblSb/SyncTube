package server;

import sys.FileSystem;
import js.node.Buffer;
import haxe.io.Path;
import js.node.Fs;
import js.node.Https;
import js.node.Http;
import js.node.url.URL;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.node.http.ClientRequest;
import js.node.Path as JsPath;
using StringTools;

class HttpServer {

	static final mimeTypes = [
		"html" => "text/html",
		"js" => "text/javascript",
		"css" => "text/css",
		"json" => "application/json",
		"png" => "image/png",
		"jpg" => "image/jpg",
		"gif" => "image/gif",
		"svg" => "image/svg+xml",
		"ico" => "image/x-icon",
		"wav" => "audio/wav",
		"mp3" => "audio/mpeg",
		"mp4" => "video/mp4",
		"woff" => "application/font-woff",
		"ttf" => "application/font-ttf",
		"eot" => "application/vnd.ms-fontobject",
		"otf" => "application/font-otf",
		"wasm" => "application/wasm"
	];

	static var dir:String;
	static var customDir:String;
	static var hasCustomRes = false;
	static var allowedLocalFiles:Map<String, Bool> = [];
	static var allowLocalRequests = false;

	public static function init(dir:String, ?customDir:String, allowLocalRequests:Bool):Void {
		HttpServer.dir = dir;
		if (customDir == null) return;
		HttpServer.customDir = customDir;
		hasCustomRes = FileSystem.exists(customDir);
		HttpServer.allowLocalRequests = allowLocalRequests;
	}

	public static function serveFiles(req:IncomingMessage, res:ServerResponse):Void {
		var url = req.url;
		if (url == "/") url = "/index.html";
		var filePath = dir + url;

		if (allowLocalRequests && req.connection.remoteAddress == req.connection.localAddress
			|| allowedLocalFiles[url]) {
			if (serveLocalFile(res, url)) return;
		}

		if (!isChildOf(dir, filePath)) {
			res.statusCode = 500;
			var rel = JsPath.relative(dir, filePath);
			res.end('Error getting the file: No access to $rel.');
			return;
		}

		if (url.startsWith("/proxy")) {
			if (!proxyUrl(req, res)) res.end('Cannot proxy ${req.url}');
			return;
		}

		if (hasCustomRes) {
			final path = customDir + url;
			if (Fs.existsSync(path)) {
				filePath = path;
				if (FileSystem.isDirectory(filePath)) {
					filePath = Path.addTrailingSlash(filePath) + "index.html";
				}
			}
		}

		Fs.readFile(filePath, (err:Dynamic, data:Buffer) -> {
			if (err != null) {
				readFileError(err, res, filePath);
				return;
			}
			final ext = Path.extension(filePath).toLowerCase();
			res.setHeader("Content-Type", getMimeType(ext));
			if (ext == "html") {
				// replace ${textId} to localized strings
				data = cast localizeHtml(data.toString(), req.headers["accept-language"]);
			}
			res.end(data);
		});
	}

	static function readFileError(err:Dynamic, res:ServerResponse, filePath:String):Void {
		if (err.code == "ENOENT") {
			res.statusCode = 404;
			var rel = JsPath.relative(dir, filePath);
			res.end('File $rel not found.');
		} else {
			res.statusCode = 500;
			res.end('Error getting the file: $err.');
		}
	}

	static function serveLocalFile(res:ServerResponse, filePath:String):Bool {
		final ext = Path.extension(filePath).toLowerCase();
		if (ext != "mp4" && ext != "mp3" && ext != "wav") return false;
		if (!Fs.existsSync(filePath)) return false;
		allowedLocalFiles[filePath] = true;
		Fs.readFile(filePath, (err:Dynamic, data:Buffer) -> {
			if (err != null) {
				readFileError(err, res, filePath);
				return;
			}
			res.setHeader("Content-Type", getMimeType(ext));
			res.end(data);
		});
		return true;
	}

	static final matchLang = ~/^[A-z]+/;
	static final matchVarString = ~/\${([A-z_]+)}/g;

	static function localizeHtml(data:String, lang:String):String {
		if (lang != null && matchLang.match(lang)) {
			lang = matchLang.matched(0);
		} else lang = "en";
		data = matchVarString.map(data, (regExp) -> {
			final key = regExp.matched(1);
			return Lang.get(lang, key);
		});
		return data;
	}

	static function proxyUrl(req:IncomingMessage, res:ServerResponse):Bool {
		final url = req.url.replace("/proxy?url=", "");
		final proxy = proxyRequest(url, req, res, proxyReq -> {
			final url = proxyReq.headers["location"];
			if (url == null) return false;
			final proxy2 = proxyRequest(url, req, res, proxyReq -> false);
			if (proxy2 == null) {
				res.end('Proxy error for redirected $url');
				return true;
			}
			req.pipe(proxy2, {end: true});
			return true;
		});
		if (proxy == null) return false;
		req.pipe(proxy, {end: true});
		return true;
	}

	static function proxyRequest(
		url:String, req:IncomingMessage, res:ServerResponse,
		fn:(req:IncomingMessage)->Bool
	):Null<ClientRequest> {
		final url = try {
			new URL(js.Node.global.decodeURI(url));
		} catch (e) return null;
		if (url.host == req.headers["host"]) return null;
		final options = {
			host: url.host,
			port: Std.parseInt(url.port),
			path: url.pathname + url.search,
			method: req.method
		};
		final request = url.protocol == "https:" ? Https.request : Http.request;
		final proxy = request(options, proxyReq -> {
			if (fn(proxyReq)) return;
			proxyReq.headers["Content-Type"] = "application/octet-stream";
			res.writeHead(proxyReq.statusCode, proxyReq.headers);
			proxyReq.pipe(res, {end: true});
		});
		proxy.on("error", err -> {
			res.end('Proxy error for ${url.href}');
		});
		return proxy;
	}

	static function isChildOf(parent:String, child:String):Bool {
		final rel = JsPath.relative(parent, child);
		return rel.length > 0 && !rel.startsWith('..') && !JsPath.isAbsolute(rel);
	}

	static function getMimeType(ext:String):String {
		final contentType = mimeTypes[ext];
		if (contentType == null) return "application/octet-stream";
		return contentType;
	}

}
