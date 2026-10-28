package tools;

import haxe.io.Path;

class PathTools {
	/** Returns extension part from `url` string or `""`. **/
	public static function urlExtension(url:String) {
		return Path.extension(~/[#?]/.split(url)[0]).trim();
	}

	public static inline function decodeURIComponent(data:String):String {
		#if js
		return js.Syntax.code("decodeURIComponent({0})", data);
		#else
		return data.replace("+", "%2B").urlDecode();
		#end
	}
}
