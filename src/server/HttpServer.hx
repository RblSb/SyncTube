package server;

import Types.UploadResponse;
import haxe.Timer;
import haxe.io.Path;
import js.lib.Error;
import js.node.Buffer;
import js.node.Fs.Fs;
import js.node.Path as JsPath;
import js.node.Stream;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.node.stream.Readable.IReadable;
import js.node.stream.Writable.IWritable;
import js.node.url.URL;
import json2object.ErrorUtils;
import json2object.JsonParser;
import server.cache.Cache;
import sys.FileSystem;

@:forward
private abstract SystemError(Error) from Error to Error {
	public var code(get, never):Null<String>;

	inline function get_code() {
		return (this : Dynamic).code;
	}
}

@:structInit
private class HttpServerConfig {
	public final dir:String;
	public final customDir:Null<String> = null;
	public final allowLocalRequests = false;
	public final enableCORS = false;
	public final enableProxy = false;
	public final cache:Cache = null;
}

typedef SetupAdminRequest = {
	name:String,
	password:String,
	passwordConfirmation:String,
}

class HttpServer {
	static final mimeTypes = [
		"html" => "text/html",
		"js" => "text/javascript",
		"mjs" => "text/javascript",
		"css" => "text/css",
		"json" => "application/json",
		"map" => "application/json",
		"txt" => "text/plain; charset=utf-8",
		"xml" => "application/xml",
		"webmanifest" => "application/manifest+json",
		"png" => "image/png",
		"jpg" => "image/jpeg",
		"jpeg" => "image/jpeg",
		"gif" => "image/gif",
		"webp" => "image/webp",
		"avif" => "image/avif",
		"svg" => "image/svg+xml",
		"ico" => "image/x-icon",
		"wav" => "audio/wav",
		"mp3" => "audio/mpeg",
		"m4a" => "audio/mp4",
		"flac" => "audio/flac",
		"ogg" => "audio/ogg",
		"opus" => "audio/ogg",
		"mp4" => "video/mp4",
		"webm" => "video/webm",
		"woff" => "font/woff",
		"woff2" => "font/woff2",
		"ttf" => "font/ttf",
		"otf" => "font/otf",
		"eot" => "application/vnd.ms-fontobject",
		"wasm" => "application/wasm"
	];
	static final ctrlCharacters = ~/[\u0000-\u001F\u007F-\u009F\u2000-\u200D\uFEFF]/g;
	static final matchRange = ~/^bytes=(\d*)-(\d*)$/;
	static final matchLang = ~/^[A-Za-z]+/;
	static final matchVarString = ~/\${([A-Za-z0-9_]+)}/g;
	static final MAX_SETUP_BODY_SIZE = 16 * 1024;
	static final MAX_LAST_CHUNKS = 16;
	static final CHUNK_SIZE = 1024 * 1024 * 5; // 5 MB

	final main:Main;
	final dir:String;
	final customDir:String;
	final hasCustomRes:Bool;
	final allowedLocalFiles:Map<String, Bool> = [];
	final allowLocalRequests:Bool;
	final enableCORS:Bool;
	final enableProxy:Bool;
	final cache:Cache;
	// temp media data while file is uploading to allow instant streaming
	// first last chunk is uploaded with `/upload-last-chunk` and returns url for full file
	final uploadingFilesLastChunks:Map<String, Buffer> = [];
	// then `/upload` gets size from `Content-Length` and sets it
	// so `serveMedia` streaming works while file is uploading
	final uploadingFilesSizes:Map<String, Float> = [];

	public function new(main:Main, config:HttpServerConfig):Void {
		this.main = main;
		dir = config.dir;
		customDir = config.customDir;
		allowLocalRequests = config.allowLocalRequests;
		enableCORS = config.enableCORS;
		enableProxy = config.enableProxy;
		cache = config.cache;

		hasCustomRes = customDir != null && FileSystem.exists(customDir);
	}

	public function serveFiles(req:IncomingMessage, res:ServerResponse):Void {
		final url = try {
			new URL(req.url, "http://localhost");
		} catch (e) {
			new URL("/", "http://localhost");
		}
		final pathname = safeDecodeURI(url.pathname);

		res.setHeader("x-content-type-options", "nosniff");

		if (enableCORS) {
			res.setHeader("access-control-allow-origin", "*");
			res.setHeader("access-control-allow-headers", "content-type, range, content-name");
			res.setHeader("access-control-expose-headers", "accept-ranges, content-encoding, content-length, content-range");
			if (req.method == "OPTIONS") {
				res.setHeader("access-control-allow-methods", "GET, HEAD, OPTIONS");
				res.statusCode = 204;
				res.end();
				return;
			}
		}

		if (req.method == "POST") {
			switch pathname {
				case "/upload-last-chunk" if (cache != null):
					uploadFileLastChunk(req, res);
				case "/upload" if (cache != null):
					uploadFile(req, res);
				case "/setup":
					finishSetup(req, res);
				case _:
					sendText(res, 404, "Not found.");
			}
			return;
		}

		if (req.method != "GET" && req.method != "HEAD") {
			res.setHeader("allow", enableCORS ? "GET, HEAD, POST, OPTIONS" : "GET, HEAD, POST");
			sendText(res, 405, "Method not allowed.");
			return;
		}

		if (pathname == "/proxy") {
			if (!enableProxy) {
				sendText(res, 400, "Proxy error: bad request");
				return;
			}
			HttpProxy.proxyUrl(req, res, url);
			return;
		}

		if (pathname == "/setup") {
			if (main.hasAdmins()) {
				res.redirect("/");
				return;
			}
		}

		var filePath = pathname == "/setup" ? '$dir/setup.html' : getPath(dir, pathname);
		var ext = Path.extension(filePath).toLowerCase();
		res.setHeader("content-type", getMimeType(ext));

		if (isLocalRequest(req) || allowedLocalFiles[pathname]) {
			if (isMediaExtension(ext) && serveMedia(req, res, pathname)) {
				if (!allowedLocalFiles.exists(pathname)
					&& allowedLocalFiles.count() >= MAX_LAST_CHUNKS) {
					allowedLocalFiles.clear();
				}
				allowedLocalFiles[pathname] = true;
				return;
			}
		}

		if (!isChildOf(dir, filePath)) {
			sendText(res, 403, "Error getting the file: No access.");
			return;
		}

		if (hasCustomRes && pathname != "/setup") {
			final path = getPath(customDir, pathname);
			if (isChildOf(customDir, path) && Fs.existsSync(path)) {
				filePath = path;
				ext = Path.extension(filePath).toLowerCase();
				res.setHeader("content-type", getMimeType(ext));
			}
		}

		if (isMediaExtension(ext)) {
			if (serveMedia(req, res, filePath)) return;
		}

		if (ext == "html" && pathname != "/setup" && !main.isNoState && !main.hasAdmins()) {
			res.redirect("/setup");
			return;
		}

		Fs.readFile(filePath, (err, data:Buffer) -> {
			if (err != null) {
				readFileError(err, res, filePath);
				return;
			}
			if (req.method == "HEAD") {
				res.end();
				return;
			}
			if (ext == "html") {
				// replace ${textId} to localized strings
				final html = localizeHtml(data.toString(), getLang(req));
				res.end(html);
				return;
			}
			res.end(data);
		});
	}

	function getUploadName(req:IncomingMessage):Null<String> {
		final raw:String = req.headers["content-name"] ?? return null;
		final decoded = try raw.decodeURIComponent() catch (e) "";
		final name = Path.withoutDirectory(ctrlCharacters.replace(decoded, "").trim());
		final base = Path.withoutExtension(name);
		final ext = Path.extension(name).toLowerCase();
		if (base.length == 0 || base == "." || !isMediaExtension(ext)) return null;
		return name;
	}

	function getFreeUploadName(req:IncomingMessage):String {
		final rawName = getUploadName(req) ?? "video.mp4";
		return cache.getFreeFileName(rawName, name -> {
			final path = JsPath.normalize(cache.getFilePath(name));
			return uploadingFilesLastChunks.exists(path) || uploadingFilesSizes.exists(path);
		});
	}

	function pickUploadName(req:IncomingMessage):String {
		final reqName = getUploadName(req);
		final reqPath = reqName != null ? JsPath.normalize(cache.getFilePath(reqName)) : null;
		return (reqPath != null
			&& uploadingFilesLastChunks.exists(reqPath)
			&& !uploadingFilesSizes.exists(reqPath)
			&& !cache.isFileExists(reqName)) ? reqName : getFreeUploadName(req);
	}

	function uploadFileLastChunk(req:IncomingMessage, res:ServerResponse):Void {
		final name = getFreeUploadName(req);
		final filePath = JsPath.normalize(cache.getFilePath(name));
		if (!uploadingFilesLastChunks.exists(filePath)
			&& uploadingFilesLastChunks.count() >= MAX_LAST_CHUNKS) {
			respondAndClose(req, res, 503, {
				info: "Too many pending uploads.",
				errorId: "tooManyUploads"});
			return;
		}
		readBody(req, res, CHUNK_SIZE, buffer -> {
			uploadingFilesLastChunks[filePath] = buffer;
			Timer.delay(() -> {
				if (uploadingFilesLastChunks[filePath] == buffer
					&& !uploadingFilesSizes.exists(filePath)) {
					uploadingFilesLastChunks.remove(filePath);
				}
			}, 60000);
			final json:UploadResponse = {
				info: "File last chunk uploaded",
				url: cache.getFileUrl(name)
			}
			res.status(200).json(json);
		});
	}

	function uploadFile(req:IncomingMessage, res:ServerResponse):Void {
		final name = pickUploadName(req);
		final filePath = JsPath.normalize(cache.getFilePath(name));
		final size = Std.parseFloat(req.headers["content-length"]);
		if (Math.isNaN(size) || size < 0) {
			respondAndClose(req, res, 411, {info: "Content-Length required."});
			return;
		}

		inline function cleanUploadState():Void {
			uploadingFilesSizes.remove(filePath);
			uploadingFilesLastChunks.remove(filePath);
		}

		if (size < cache.storageLimit) {
			// do not remove older cache if file is out of limit anyway
			cache.removeOlderCache(size);
		}
		if (cache.getFreeSpace() < size) {
			cleanUploadState();
			respondAndClose(req, res, 413, { // Payload Too Large
				info: cache.notEnoughSpaceErrorText,
				errorId: "freeSpace",
			});
			return;
		}

		final stream = Fs.createWriteStream(filePath);
		cache.add(name);
		uploadingFilesSizes[filePath] = size;

		pipeline(req, stream, err -> {
			cleanUploadState();
			if (err == null) {
				res.status(200).json({info: "File write stream closed."});
				return;
			}
			onPipelineDone(err);
			cache.remove(name);
			if (!res.headersSent) {
				res.status(500).json({info: "File write stream error."});
			}
		});
	}

	function finishSetup(req:IncomingMessage, res:ServerResponse):Void {
		if (main.hasAdmins()) {
			res.redirect("/");
			return;
		}

		readBody(req, res, MAX_SETUP_BODY_SIZE, buffer -> {
			if (main.hasAdmins()) {
				res.status(409).json({success: false, errors: []});
				return;
			}
			final body = buffer.toString();
			final jsonParser = new JsonParser<SetupAdminRequest>();
			final jsonData = jsonParser.fromJson(body);
			if (jsonData == null || jsonParser.errors.length > 0) {
				if (jsonParser.errors.length > 0) {
					trace(ErrorUtils.convertErrorArray(jsonParser.errors));
				}
				res.status(400).json({success: false, errors: []});
				return;
			}
			final name = jsonData.name ?? "";
			final password = jsonData.password ?? "";
			final passwordConfirmation = jsonData.passwordConfirmation ?? "";
			final lang = getLang(req);
			final errors:Array<{type:String, error:String}> = [];

			if (main.isBadClientName(name)) {
				final error = Lang.get(lang, "usernameError")
					.replace("$MAX", '${main.config.maxLoginLength}');
				errors.push({
					type: "name",
					error: error
				});
			}

			final min = Main.MIN_PASSWORD_LENGTH;
			final max = Main.MAX_PASSWORD_LENGTH;
			if (password.length < min || password.length > max) {
				final error = Lang.get(lang, "passwordError")
					.replace("$MIN", '$min').replace("$MAX", '$max');
				errors.push({
					type: "password",
					error: error
				});
			}

			if (password != passwordConfirmation) {
				errors.push({
					type: "password",
					error: Lang.get(lang, "passwordsMismatchError")
				});
			}

			if (errors.length > 0) {
				res.status(400).json({success: false, errors: errors});
				return;
			}

			main.addAdmin(name, password);
			res.status(200).json({success: true});
		});
	}

	function getPath(dir:String, pathname:String):String {
		final filePath = dir + pathname;
		if (pathname != "/"
			&& (!isChildOf(dir, filePath) || !FileSystem.isDirectory(filePath))) return
				filePath;
		return Path.addTrailingSlash(filePath) + "index.html";
	}

	function readFileError(err:SystemError, res:ServerResponse, filePath:String):Void {
		if (err.code == "ENOENT") {
			final rel = JsPath.relative(dir, filePath);
			sendText(res, 404, 'File $rel not found.');
		} else {
			sendText(res, 500, "Error getting the file.");
		}
	}

	function serveMedia(req:IncomingMessage, res:ServerResponse, filePath:String):Bool {
		final stats = try Fs.statSync(filePath) catch (e) return false;
		if (!stats.isFile()) return false;
		final key = JsPath.normalize(filePath);
		final isUploading = uploadingFilesSizes.exists(key);
		final videoSize:Float = isUploading ? uploadingFilesSizes[key] : stats.size;
		res.setHeader("accept-ranges", "bytes");
		final isHead = req.method == "HEAD";
		final rangeHeader:String = req.headers["range"];
		final range = rangeHeader == null ? null : parseRangeHeader(rangeHeader, videoSize);
		if (range == null) {
			final contentLength:Float = isUploading ? stats.size : videoSize;
			res.statusCode = 200;
			res.setHeader("content-length", '$contentLength');
			if (isHead || contentLength == 0) res.end();
			else pipeFile(res, filePath, {start: 0, end: contentLength - 1});
			return true;
		}
		if (range.start >= videoSize || range.start > range.end) {
			send416(res, videoSize);
			return true;
		}
		final start = range.start;
		var end = range.end;

		// check for last chunk cache for instant play while uploading
		final buffer = uploadingFilesLastChunks[key];
		if (buffer != null && start >= videoSize - buffer.byteLength) {
			setRange(res, start, end, videoSize);
			if (isHead) {
				res.end();
				return true;
			}
			final offset = videoSize - buffer.byteLength;
			res.end(buffer.subarray(Std.int(start - offset), Std.int(end - offset + 1)));
			return true;
		}

		if (isUploading) {
			if (start >= stats.size) {
				send416(res, videoSize);
				return true;
			}
			if (end >= stats.size) end = stats.size - 1;
		}

		setRange(res, start, end, videoSize);
		if (isHead) {
			res.end();
			return true;
		}

		// stream the video chunk to the client
		pipeFile(res, filePath, {start: start, end: end});
		return true;
	}

	static function send416(res:ServerResponse, size:Float):Void {
		res.statusCode = 416; // range not satisfiable
		res.setHeader("content-range", 'bytes */$size');
		res.end();
	}

	static function setRange(res:ServerResponse, start:Float, end:Float, size:Float):Void {
		final contentLength = end - start + 1;
		res.setHeader("content-range", 'bytes $start-$end/$size');
		res.setHeader("content-length", '$contentLength');
		res.statusCode = 206; // partial content
	}

	function pipeFile(res:ServerResponse, filePath:String, ?options:{?start:Float, ?end:Float}):Void {
		final stream = Fs.createReadStream(filePath, cast options);
		pipeline(stream, res, onPipelineDone);
	}

	function parseRangeHeader(rangeHeader:String, size:Float):Null<{start:Float, end:Float}> {
		if (!matchRange.match(rangeHeader.trim())) return null;
		final s = matchRange.matched(1);
		final e = matchRange.matched(2);
		var start:Float;
		var end:Float;
		if (s == "") {
			// handle file end requests like `bytes=-500`
			if (e == "") return null;
			final suffix = Std.parseFloat(e);
			if (suffix == 0) return {start: size, end: size - 1};
			start = (size - suffix).limitMin(0);
			end = size - 1;
		} else {
			start = Std.parseFloat(s);
			end = e == "" ? start + CHUNK_SIZE - 1 : Std.parseFloat(e);
		}
		end = end.limitMax(size - 1);
		return {start: start, end: end};
	}

	function isMediaExtension(ext:String):Bool {
		final mime = getMimeType(ext);
		return mime.startsWith("audio/") || mime.startsWith("video/");
	}

	function getLang(req:IncomingMessage):String {
		final header:String = req.headers["accept-language"];
		if (header != null && matchLang.match(header)) {
			return matchLang.matched(0).toLowerCase();
		}
		return "en";
	}

	function localizeHtml(data:String, lang:String):String {
		if (!data.contains("<!-- localization-template -->")) return data;
		return matchVarString.map(data, regExp -> {
			final key = regExp.matched(1);
			return Lang.get(lang, key);
		});
	}

	function isLocalRequest(req:IncomingMessage):Bool {
		return allowLocalRequests
			&& req.socket.remoteAddress == req.socket.localAddress
			&& req.headers["x-forwarded-for"] == null
			&& req.headers["sec-fetch-site"] != "cross-site";
	}

	function readBody(
		req:IncomingMessage,
		res:ServerResponse,
		maxSize:Int,
		onBody:Buffer->Void
	):Void {
		final chunks:Array<Buffer> = [];
		var size = 0;
		var rejected = false;
		req.on("data", (chunk:Buffer) -> {
			if (rejected) return;
			size += chunk.length;
			if (size > maxSize) {
				rejected = true;
				chunks.resize(0);
				req.pause();
				respondAndClose(req, res, 413, {
					info: "Payload too large.",
					errorId: "payloadTooLarge",
					success: false,
					errors: []
				});
				return;
			}
			chunks.push(chunk);
		});
		req.on("end", () -> {
			if (!rejected) onBody(Buffer.concat(chunks));
		});
	}

	function respondAndClose(req:IncomingMessage, res:ServerResponse, code:Int, json:Any):Void {
		res.setHeader("connection", "close");
		res.once("finish", () -> req.destroy());
		res.status(code).json(json);
	}

	public static function sendText(res:ServerResponse, code:Int, text:String):Void {
		if (res.headersSent) {
			if (!res.writableEnded) res.end();
			return;
		}
		res.statusCode = code;
		res.setHeader("content-type", getMimeType("txt"));
		res.end(text);
	}

	public static function pipeline(src:IReadable, dst:IWritable, ?cb:Null<SystemError>->Void):Void {
		cb ??= onPipelineDone;
		Stream.pipeline(src, dst, cb);
	}

	static function onPipelineDone(err:Null<SystemError>):Void {
		if (err != null && err.code != "ERR_STREAM_PREMATURE_CLOSE") {
			trace("Stream error:", err);
		}
	}

	static function getMimeType(ext:String):String {
		return mimeTypes[ext] ?? "application/octet-stream";
	}

	function isChildOf(parent:String, child:String):Bool {
		final rel = JsPath.relative(parent, child);
		return rel.length > 0
			&& rel != ".."
			&& !rel.startsWith('..${JsPath.sep}')
			&& !JsPath.isAbsolute(rel);
	}

	function safeDecodeURI(data:String):String {
		try {
			data = data.decodeURIComponent();
		} catch (err) {
			return "/";
		}
		data = ctrlCharacters.replace(data, "");
		if (data.trim() == "/") return "/";
		return data;
	}
}
