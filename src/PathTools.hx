package;

import haxe.io.Path;

class PathTools {
	public static function urlExtension(url:String) {
		return Path.extension(~/[#?]/.split(url)[0]).trim().toLowerCase();
	}
}
