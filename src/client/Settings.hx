package client;

import haxe.Json;
import js.Browser;
import js.html.Storage;

private typedef Vers = {version:Int};
private typedef Updater = (data:Any, version:Int) -> Any;

class Settings {
	static var defaults:Null<Vers>;
	static var updater:Null<Updater>;
	static var storage:Storage;
	static var isSupported = false;

	public static function init(def:Vers, ?upd:Updater):Void {
		storage = Browser.getLocalStorage();
		isSupported = storage != null;
		defaults = def;
		updater = upd;
	}

	public static function read():Any {
		if (!isSupported) return defaults;
		final data:Any = Json.parse(storage.getItem("data"));
		return checkData(data);
	}

	static function checkData(data:Vers):Any {
		if (defaults == null) throw "read: default data is null";
		if (data == null) return defaults;
		if (data.version == defaults.version) return data;
		if (data.version > defaults.version)
			throw "read: current data version is larger than default data version";
		if (updater == null) throw "read: updater function is null";
		while (data.version < defaults.version) {
			data = updater(data, data.version);
			data.version++;
		}
		write(data);
		return data;
	}

	public static function set(sets:Any):Void {
		final data = read();
		final fields = Reflect.fields(sets);
		for (field in fields) {
			final value = Reflect.field(sets, field);
			Reflect.setField(data, field, value);
		}
		write(data);
	}

	public static function write(data:Vers):Void {
		if (!isSupported) return;
		storage.setItem("data", Json.stringify(data));
	}

	public static function reset():Void {
		if (defaults == null) throw "reset: default data is null";
		write(defaults);
	}
}
