package server;

import js.node.Buffer;
import haxe.io.Path;
import js.node.Fs;
import sys.io.File;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.Node.__dirname;
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

	public static function init(directory:String):Void {
		dir = directory;
	}

	public static function serveFiles(req:IncomingMessage, res:ServerResponse):Void {
		var filePath = dir + req.url;
		if (req.url == "/") filePath = '$dir/index.html';

		final extension = Path.extension(filePath).toLowerCase();
		final contentType = getMimeType(extension);

		if (!isChildOf(dir, filePath)) {
			res.statusCode = 500;
			var rel = JsPath.relative(dir, filePath);
			res.end('Error getting the file: No access to $rel.');
			return;
		}

		// load client code from build folder
		if (filePath == '$dir/client.js') {
			filePath = '$__dirname/client.js';
		}

		Fs.readFile(filePath, function(err:Dynamic, data:Buffer) {
			if (err != null) {
				if (err.code == "ENOENT") {
					res.statusCode = 404;
					var rel = JsPath.relative(dir, filePath);
					res.end('File $rel not found.');
				} else {
					res.statusCode = 500;
					res.end('Error getting the file: $err.');
				}
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

	static final matchLang = ~/^[A-z]+/;

	static function localizeHtml(data:String, lang:String):String {
		if (lang != null && matchLang.match(lang)) {
			lang = matchLang.matched(0);
		} else lang = "en";
		data = ~/\${([A-z_]+)}/g.map(data, (regExp) -> {
			final key = regExp.matched(1);
			return Lang.get(lang, key);
		});
		return data;
	}

	static function isChildOf(parent:String, child:String):Bool {
		final path = JsPath;
		final relative = path.relative(parent, child);
		return relative.length > 0 && !relative.startsWith('..') && !path.isAbsolute(relative);
	}

	static function getMimeType(ext:String):String {
		var contentType = mimeTypes[ext];
		if (contentType == null) contentType = "application/octet-stream";
		return contentType;
	}

}
