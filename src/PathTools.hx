package;

import haxe.io.Path;

using StringTools;

class PathTools {
	public static function urlExtension(url:String) {
		return Path.extension(~/[#?]/.split(url)[0]).trim().toLowerCase();
	}
}
