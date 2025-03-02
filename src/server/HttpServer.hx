package server;

import Types.UploadResponse;
import haxe.Json;
import haxe.io.Path;
import js.node.Buffer;
import js.node.Fs.Fs;
import js.node.Http;
import js.node.Https;
import js.node.Path as JsPath;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.node.url.URL;
import sys.FileSystem;

@:structInit
private class HttpServerConfig {
	public final dir:String;
	public final customDir:String = null;
	public final allowLocalRequests = false;
	public final cache:Cache = null;
}

class HttpServer {
	static final mimeTypes = [
		"html" => "text/html",
		"js" => "text/javascript",
		"css" => "text/css",
		"json" => "application/json",
		"png" => "image/png",
		"jpg" => "image/jpeg",
		"jpeg" => "image/jpeg",
		"gif" => "image/gif",
		"webp" => "image/webp",
		"svg" => "image/svg+xml",
		"ico" => "image/x-icon",
		"wav" => "audio/wav",
		"mp3" => "audio/mpeg",
		"mp4" => "video/mp4",
		"webm" => "video/webm",
		"woff" => "application/font-woff",
		"ttf" => "application/font-ttf",
		"eot" => "application/vnd.ms-fontobject",
		"otf" => "application/font-otf",
		"wasm" => "application/wasm"
	];

	final main:Main;
	final dir:String;
	final customDir:String;
	final hasCustomRes = false;
	final allowedLocalFiles:Map<String, Bool> = [];
	final allowLocalRequests = false;
	final cache:Cache = null;
	final CHUNK_SIZE = 1024 * 1024 * 5; // 5 MB
	// temp media data while file is uploading to allow instant streaming
	final uploadingFilesSizes:Map<String, Int> = [];
	final uploadingFilesLastChunks:Map<String, Buffer> = [];

	public function new(main:Main, config:HttpServerConfig):Void {
		this.main = main;
		dir = config.dir;
		customDir = config.customDir;
		allowLocalRequests = config.allowLocalRequests;
		cache = config.cache;

		if (customDir != null) hasCustomRes = FileSystem.exists(customDir);
	}

	public function serveFiles(req:IncomingMessage, res:ServerResponse):Void {
		final url = try {
			new URL(safeDecodeURI(req.url), "http://localhost");
		} catch (e) {
			new URL("/", "http://localhost");
		}
		var filePath = getPath(dir, url);
		final ext = Path.extension(filePath).toLowerCase();

		res.setHeader("accept-ranges", "bytes");
		res.setHeader("content-type", getMimeType(ext));

		if (cache != null && req.method == "POST") {
			switch url.pathname {
				case "/upload-last-chunk":
					uploadFileLastChunk(req, res);
				case "/upload":
					uploadFile(req, res);
			}
			return;
		}

		if (allowLocalRequests && req.socket.remoteAddress == req.socket.localAddress
			|| allowedLocalFiles[url.pathname]) {
			if (isMediaExtension(ext)) {
				allowedLocalFiles[url.pathname] = true;
				if (serveMedia(req, res, url.pathname.urlDecode())) return;
			}
		}

		if (!isChildOf(dir, filePath)) {
			res.statusCode = 500;
			var rel = JsPath.relative(dir, filePath);
			res.end('Error getting the file: No access to $rel.');
			return;
		}

		if (url.pathname == "/proxy") {
			if (!proxyUrl(req, res)) res.end('Proxy error: ${req.url}');
			return;
		}

		if (hasCustomRes) {
			final path = getPath(customDir, url);
			if (Fs.existsSync(path)) filePath = path;
			final ext = Path.extension(filePath).toLowerCase();
			res.setHeader("content-type", getMimeType(ext));
		}

		if (isMediaExtension(ext)) {
			if (serveMedia(req, res, filePath)) return;
		}

		Fs.readFile(filePath, (err:Dynamic, data:Buffer) -> {
			if (err != null) {
				readFileError(err, res, filePath);
				return;
			}
			if (ext == "html") {
				// replace ${textId} to localized strings
				data = cast localizeHtml(data.toString(), req.headers["accept-language"]);
			}
			res.end(data);
		});
	}

	function uploadFileLastChunk(req:IncomingMessage, res:ServerResponse) {
		var fileName = try decodeURIComponent(req.headers["content-name"]) catch (e) "";
		if (fileName.trim().length == 0) fileName = null;
		final name = cache.getFreeFileName(fileName);
		final filePath = cache.getFilePath(name);
		final body:Array<Any> = [];
		req.on("data", chunk -> body.push(chunk));
		req.on("end", () -> {
			final buffer = Buffer.concat(body);
			uploadingFilesLastChunks[filePath] = buffer;
			res.writeHead(200, {
				"content-type": getMimeType("json"),
			});
			final json:UploadResponse = {
				info: "File last chunk uploaded",
				url: cache.getFileUrl(name)
			}
			res.end(Json.stringify(json));
		});
	}

	function uploadFile(req:IncomingMessage, res:ServerResponse) {
		var fileName = try decodeURIComponent(req.headers["content-name"]) catch (e) "";
		if (fileName.trim().length == 0) fileName = null;
		final name = cache.getFreeFileName(fileName);
		final filePath = cache.getFilePath(name);
		final size = Std.parseInt(req.headers["content-length"]) ?? return;

		inline function end(code:Int, json:UploadResponse):Void {
			res.statusCode = code;
			res.end(Json.stringify(json));

			uploadingFilesSizes.remove(filePath);
			uploadingFilesLastChunks.remove(filePath);
		}

		if (size < cache.storageLimit) {
			// do not remove older cache if file is out of limit anyway
			cache.removeOlderCache(size);
		}
		if (cache.getFreeSpace() < size) {
			end(413, { // Payload Too Large
				info: cache.notEnoughSpaceErrorText,
				errorId: "freeSpace",
			});
			cache.remove(name);
			req.destroy();
			final client = main.clients.getByName(name) ?? return;
			main.serverMessage(client, cache.notEnoughSpaceErrorText);
			return;
		}

		final stream = Fs.createWriteStream(filePath);
		req.pipe(stream);

		cache.add(name);
		uploadingFilesSizes[filePath] = size;

		stream.on("close", () -> {
			end(200, {
				info: "File write stream closed.",
			});
		});
		stream.on("error", err -> {
			trace(err);
			end(500, {
				info: "File write stream error.",
			});
			cache.remove(name);
		});
		req.on("error", err -> {
			trace("Request Error:", err);
			stream.destroy();
			end(500, {
				info: "File request error.",
			});
			cache.remove(name);
		});
	}

	function getPath(dir:String, url:URL):String {
		final filePath = dir.urlDecode() + decodeURIComponent(url.pathname);
		if (!FileSystem.isDirectory(filePath)) return filePath;
		return Path.addTrailingSlash(filePath) + "index.html";
	}

	function readFileError(err:Dynamic, res:ServerResponse, filePath:String):Void {
		res.setHeader("content-type", getMimeType("html"));
		if (err.code == "ENOENT") {
			res.statusCode = 404;
			var rel = JsPath.relative(dir, filePath);
			res.end('File $rel not found.');
		} else {
			res.statusCode = 500;
			res.end('Error getting the file: $err.');
		}
	}

	function serveMedia(req:IncomingMessage, res:ServerResponse, filePath:String):Bool {
		if (!Fs.existsSync(filePath)) return false;
		var videoSize:Int = cast Fs.statSync(filePath).size;
		// use future content length to start playing it before uploaded
		if (uploadingFilesSizes.exists(filePath)) {
			videoSize = uploadingFilesSizes[filePath];
		}
		final rangeHeader:String = req.headers["range"];
		if (rangeHeader == null) {
			res.statusCode = 200;
			res.setHeader("content-length", '$videoSize');
			final videoStream = Fs.createReadStream(filePath);
			videoStream.pipe(res);
			res.on("error", () -> videoStream.destroy());
			res.on("close", () -> videoStream.destroy());
			return true;
		}
		final range = parseRangeHeader(rangeHeader, videoSize);
		final start = range.start;
		final end = range.end;
		final contentLength = end - start + 1;

		res.setHeader("content-range", 'bytes $start-$end/$videoSize');
		res.setHeader("content-length", '$contentLength');
		res.statusCode = 206; // partial content

		// check for last chunk cache for instant play while uploading
		final buffer = uploadingFilesLastChunks[filePath];
		if (buffer != null && end == videoSize - 1 && contentLength < buffer.byteLength) {
			final bufferStart = (buffer.byteLength - contentLength).limitMin(0);
			res.end(buffer.slice(bufferStart));
			return true;
		}

		// stream the video chunk to the client
		final videoStream = Fs.createReadStream(
			filePath,
			{start: start, end: end}
		);
		videoStream.pipe(res);
		res.on("error", () -> videoStream.destroy());
		res.on("close", () -> videoStream.destroy());
		return true;
	}

	function parseRangeHeader(rangeHeader:String, videoSize:Int):{start:Int, end:Int} {
		final ranges = ~/[-=]/g.split(rangeHeader);
		var start = Std.parseInt(ranges[1]);
		if (Utils.isOutOfRange(start, 0, videoSize - 1)) start = 0;
		var end = Std.parseInt(ranges[2]);
		if (end == null) end = start + CHUNK_SIZE;
		if (Utils.isOutOfRange(end, start, videoSize - 1)) end = videoSize - 1;
		return {
			start: start,
			end: end
		};
	}

	function isMediaExtension(ext:String):Bool {
		return ext == "mp4" || ext == "webm" || ext == "mp3" || ext == "wav";
	}

	final matchLang = ~/^[A-z]+/;
	final matchVarString = ~/\${([A-z_]+)}/g;

	function localizeHtml(data:String, lang:String):String {
		if (lang != null && matchLang.match(lang)) {
			lang = matchLang.matched(0);
		} else lang = "en";
		data = matchVarString.map(data, (regExp) -> {
			final key = regExp.matched(1);
			return Lang.get(lang, key);
		});
		return data;
	}

	function proxyUrl(req:IncomingMessage, res:ServerResponse):Bool {
		final url = req.url.replace("/proxy?url=", "");
		final proxy = proxyRequest(url, req, res, proxyRes -> {
			final url = proxyRes.headers["location"] ?? return false;
			final proxy2 = proxyRequest(url, req, res, proxyRes -> false);
			if (proxy2 == null) {
				res.end('Proxy error: multiple redirects for url $url');
				return true;
			}
			req.pipe(proxy2);
			return true;
		});
		if (proxy == null) return false;
		req.pipe(proxy);
		return true;
	}

	function proxyRequest(
		url:String,
		req:IncomingMessage,
		res:ServerResponse,
		cancelProxyRequest:(proxyRes:IncomingMessage) -> Bool
	):Null<ClientRequest> {
		final url = try {
			new URL(safeDecodeURI(url));
		} catch (e) {
			return null;
		}
		if (url.host == req.headers["host"]) return null;
		final options = {
			host: url.hostname,
			port: Std.parseInt(url.port),
			path: url.pathname + url.search,
			method: req.method
		};
		req.headers["referer"] = url.toString();
		req.headers["host"] = url.hostname;
		final request = url.protocol == "https:" ? Https.request : Http.request;
		final proxy = request(options, proxyRes -> {
			if (cancelProxyRequest(proxyRes)) return;
			proxyRes.headers["content-type"] = "application/octet-stream";
			res.writeHead(proxyRes.statusCode, proxyRes.headers);
			proxyRes.pipe(res);
		});
		proxy.on("error", err -> {
			res.end('Proxy error: ${url.href}');
		});
		return proxy;
	}

	function isChildOf(parent:String, child:String):Bool {
		final rel = JsPath.relative(parent, child);
		return rel.length > 0 && !rel.startsWith("..") && !JsPath.isAbsolute(rel);
	}

	function getMimeType(ext:String):String {
		return mimeTypes[ext] ?? return "application/octet-stream";
	}

	final ctrlCharacters = ~/[\u0000-\u001F\u007F-\u009F\u2000-\u200D\uFEFF]/g;

	function safeDecodeURI(data:String):String {
		try {
			data = decodeURI(data);
		} catch (err) {
			data = "";
		}
		data = ctrlCharacters.replace(data, "");
		return data;
	}

	inline function decodeURI(data:String):String {
		return js.Syntax.code("decodeURI({0})", data);
	}

	inline function decodeURIComponent(data:String):String {
		return js.Syntax.code("decodeURIComponent({0})", data);
	}
}
