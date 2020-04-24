package client;

import Types.VideoItem;
import js.Browser.document;

private typedef VideoChangeFunc = (item:VideoItem)->Void;

class JsApi {

	static final videoChange:Array<VideoChangeFunc> = [];
	static final videoRemove:Array<VideoChangeFunc> = [];

	@:expose
	static function addPlugin(id:String, ?onLoaded:()->Void):Void {
		addScriptToHead('/plugins/$id/index.js', onLoaded);
	}

	@:expose
	static function addScriptToHead(url:String, ?onLoaded:()->Void):Void {
		var script = document.createScriptElement();
		script.type = "text/javascript";
		script.onload = onLoaded;
		script.src = url;
		document.getElementsByTagName("head")[0].appendChild(script);
	}

	@:expose
	static function hasScriptInHead(url:String):Bool {
		for (child in document.getElementsByTagName("head")[0].children) {
			if ((child : Dynamic).src == url) return true;
		}
		return false;
	}

	@:expose
	static function notifyOnVideoChange(func:VideoChangeFunc):Void {
		videoChange.push(func);
	}

	@:expose
	static function removeFromVideoChange(func:VideoChangeFunc):Void {
		videoChange.remove(func);
	}

	public static function fireVideoChangeEvents(item:VideoItem):Void {
		for (func in videoChange) func(item);
	}

	@:expose
	static function notifyOnVideoRemove(func:VideoChangeFunc):Void {
		videoRemove.push(func);
	}

	@:expose
	static function removeFromVideoRemove(func:VideoChangeFunc):Void {
		videoRemove.remove(func);
	}

	public static function fireVideoRemoveEvents(item:VideoItem):Void {
		for (func in videoRemove) func(item);
	}

}
