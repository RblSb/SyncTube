package client;

import Types.WsEventType;
import Types.WsEvent;
import Types.VideoItem;
import js.Browser.document;
import js.Browser.window;
import js.Syntax;

private typedef VideoChangeFunc = (item:VideoItem)->Void;
private typedef OnceEventFunc = (event:WsEvent)->Void;

class JsApi {

	static var main:Main;
	static var player:Player;
	static final videoChange:Array<VideoChangeFunc> = [];
	static final videoRemove:Array<VideoChangeFunc> = [];
	static final onceListeners:Array<{type:WsEventType, func:OnceEventFunc}> = [];

	public static function init(main:Main, player:Player):Void {
		JsApi.main = main;
		JsApi.player = player;
		initPluginsSpace();
	}

	static function initPluginsSpace():Void {
		final w:Dynamic = window;
		if (w.synctube == null) w.synctube = {};
	}

	@:expose
	static function addPlugin(id:String, ?onLoaded:()->Void):Void {
		addScriptToHead('/plugins/$id/index.js', () -> {
			final obj = {
				api: Syntax.plainCode("client.JsApi"),
				id: id,
				path: '/plugins/$id'
			}
			if (untyped window.synctube[id] == null) {
				window.console.error('Plugin "$id" not found');
			} else {
				Syntax.code("new synctube[id]({0})", obj);
				if (onLoaded != null) onLoaded();
			}
		});
	}

	@:expose
	public static function addScriptToHead(url:String, ?onLoaded:()->Void):Void {
		final script = document.createScriptElement();
		script.type = "text/javascript";
		script.onload = onLoaded;
		script.src = url;
		document.head.appendChild(script);
	}

	@:expose
	static function hasScriptInHead(url:String):Bool {
		for (child in document.getElementsByTagName("head")[0].children) {
			if ((child : Dynamic).src == url) return true;
		}
		return false;
	}

	@:expose
	static function getTime():Float {
		return player.getTime();
	}

	@:expose
	static function setTime(time:Float):Void {
		player.setTime(time);
	}

	@:expose
	static function isLeader():Bool {
		return main.isLeader();
	}

	@:expose
	static function forceSyncNextTick(flag:Bool):Void {
		main.forceSyncNextTick = flag;
	}

	@:expose
	static function setVideoSrc(src:String):Void {
		player.changeVideoSrc(src);
	}

	/** Returns current page hostname (domain without protocol) **/
	@:expose
	static function getLocalIp():String {
		return main.host;
	}

	/** Returns server global ip. **/
	@:expose
	static function getGlobalIp():String {
		return main.globalIp;
	}

	@:expose
	public static function once(type:WsEventType, func:OnceEventFunc):Void {
		onceListeners.push({type: type, func: func});
	}

	public static function fireOnceEvent(event:WsEvent):Void {
		var i = 0;
		while (i < onceListeners.length) {
			final listener = onceListeners[i];
			if (listener.type == event.type) {
				listener.func(event);
				onceListeners.remove(listener);
				continue;
			}
			i++;
		}
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
