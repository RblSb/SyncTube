package tools;

import haxe.Json;
import js.node.http.ServerResponse;

class HttpServerTools {
	public static function status(res:ServerResponse, status:Int):ServerResponse {
		res.statusCode = status;
		return res;
	}

	public static function json(res:ServerResponse, obj:Any):ServerResponse {
		res.setHeader("content-type", "application/json");
		res.end(Json.stringify(obj));
		return res;
	}

	public static function redirect(res:ServerResponse, url:String):Void {
		res.writeHead(302, {"location": url});
		res.end();
	}
}
