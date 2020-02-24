package server;

import sys.FileSystem;
import js.node.Buffer;
import haxe.io.Path;
import js.node.Fs;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
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

	public static function init(dir:String, ?customDir:String):Void {
		HttpServer.dir = dir;
		if (customDir == null) return;
		HttpServer.customDir = customDir;
		hasCustomRes = FileSystem.exists(customDir);
	}

	public static function serveFiles(req:IncomingMessage, res:ServerResponse):Void {
		var url = req.url;
		if (url == "/") url = "/index.html";
		var filePath = dir + url;

		final extension = Path.extension(filePath).toLowerCase();
		final contentType = getMimeType(extension);

		if (req.connection.remoteAddress == req.connection.localAddress
			|| allowedLocalFiles[url]) {
			final isExists = serveLocalFile(res, url, extension, contentType);
			if (isExists) return;
		}

		if (!isChildOf(dir, filePath)) {
			res.statusCode = 500;
			var rel = JsPath.relative(dir, filePath);
			res.end('Error getting the file: No access to $rel.');
			return;
		}

		if (hasCustomRes) {
			final path = customDir + url;
			if (Fs.existsSync(path)) filePath = path;
		}

		Fs.readFile(filePath, (err:Dynamic, data:Buffer) -> {
			if (err != null) {
				readFileError(err, res, filePath);
				return;
			}
			res.setHeader("Content-Type", contentType);
			if (extension == "html") {
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

	static function serveLocalFile(res:ServerResponse, filePath:String, ext:String, contentType:String):Bool {
		if (ext != "mp4" && ext != "mp3" && ext != "wav") return false;
		if (!Fs.existsSync(filePath)) return false;
		allowedLocalFiles[filePath] = true;
		Fs.readFile(filePath, (err:Dynamic, data:Buffer) -> {
			if (err != null) {
				readFileError(err, res, filePath);
				return;
			}
			res.setHeader("Content-Type", contentType);
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
