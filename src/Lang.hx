package;

import haxe.Json;
import haxe.io.Path;

using Lambda;

#if (sys || nodejs)
import sys.io.File;
#else
import haxe.Http;
#end

private typedef LangMap = Map<String, String>;

class Lang {
	static final langs:Map<String, LangMap> = [];
	static var ids = ["en", "ru"];
	#if (js && !nodejs)
	static var lang = js.Browser.navigator.language.substr(0, 2).toLowerCase();
	#end

	static function request(path:String, callback:(data:String) -> Void):Void {
		#if (sys || nodejs)
		callback(File.getContent(path));
		#else
		final http = new Http(path);
		http.onData = callback;
		http.request();
		#end
	}

	public static function init(folderPath:String, ?callback:() -> Void):Void {
		#if (js && !nodejs)
		// Filter unused languages
		ids = ids.filter(id -> id == lang || id == "en");
		#end
		langs.clear();
		var count = 0;
		for (name in ids) {
			request('$folderPath/$name.json', data -> {
				final data = Json.parse(data);
				final lang = new LangMap();
				for (key in Reflect.fields(data)) {
					lang[key] = Reflect.field(data, key);
				}
				final id = Path.withoutExtension(name);
				langs[id] = lang;
				count++;
				if (count == ids.length && callback != null) callback();
			});
		}
	}

	#if (sys || nodejs)
	public static function get(lang:String, ?key:String):String {
		if (langs[lang] == null) lang = "en";
		final text = langs[lang][key];
		return text == null ? key : text;
	}
	#else
	public static function get(key:String):String {
		if (langs[lang] == null) lang = "en";
		final text = langs[lang][key];
		return text == null ? key : text;
	}
	#end
}
