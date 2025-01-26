package client;

import Types.VideoItem;
import Types.WsEvent;
import Types.WsEventType;
import js.Browser.document;
import js.Browser.window;
import js.Syntax;

private typedef VideoChangeFunc = (item:VideoItem) -> Void;
private typedef EventCallback = (event:WsEvent) -> Void;

class JsApi {
	static var main:Main;
	static var player:Player;
	static final subtitleFormats = [];
	static final videoChange:Array<VideoChangeFunc> = [];
	static final videoRemove:Array<VideoChangeFunc> = [];
	static final onListeners:Array<{type:WsEventType, callback:EventCallback}> = [];
	static final onceListeners:Array<{type:WsEventType, callback:EventCallback}> = [];

	public static function init(main:Main, player:Player):Void {
		JsApi.main = main;
		JsApi.player = player;
		initPluginsSpace();
	}

	static function initPluginsSpace():Void {
		final w:Dynamic = window;
		w.synctube ??= {};
	}

	@:expose
	static function addPlugin(id:String, ?onLoaded:() -> Void):Void {
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
	public static function addScriptToHead(url:String, ?onLoaded:() -> Void):Void {
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
	static function getVideoItems():Array<VideoItem> {
		final items = player.getItems();
		return [
			for (item in items) Reflect.copy(item)
		];
	}

	@:expose
	static function addVideoItem(url:String, atEnd:Bool, isTemp:Bool, ?callback:() ->
		Void, doCache = false):Void {
		main.addVideo(url, atEnd, isTemp, doCache, callback);
	}

	@:expose
	static function removeVideoItem(url:String):Void {
		main.removeVideoItem(url);
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
	public static function setVideoSrc(url:String):Void {
		player.changeVideoSrc(url);
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

	/**
	 * If plugin adds any subtitle format (like `ass`),
	 * you will see subtitle input below video url input on client page.
	 * Plugins can listen to `notifyOnVideoChange(item => {...}`
	 * for raw videos and load that input data from `item.subs` url to do something.
	 * See `https://github.com/RblSb/SyncTube-octosubs` as example.
	 */
	@:expose
	static function addSubtitleSupport(format:String):Void {
		format = format.trim().toLowerCase();
		if (subtitleFormats.contains(format)) return;
		subtitleFormats.push(format);
	}

	@:expose
	public static function hasSubtitleSupport(?format:String):Bool {
		if (format == null) return subtitleFormats.length > 0;
		return subtitleFormats.contains(format);
	}

	/**
	 * Listen to server event once before that event is parsed by client.
	 * Example:
	 * `JsApi.once("RemoveVideo", event => {`
	 * `  if (event.removeVideo.url == url) {...}`
	 * `});`
	 */
	@:expose
	public static function once(type:WsEventType, callback:EventCallback):Void {
		onceListeners.unshift({type: type, callback: callback});
	}

	public static function on(type:WsEventType, callback:EventCallback):Void {
		onListeners.unshift({type: type, callback: callback});
	}

	public static function off(type:WsEventType, callback:EventCallback):Void {
		final listener = onListeners.find(item -> {
			return item.type == type && item.callback == callback;
		});
		onListeners.remove(listener);
	}

	public static function fireEvents(event:WsEvent):Void {
		for (listener in onListeners.reversed()) {
			if (listener.type != event.type) continue;
			listener.callback(event);
		}
		for (listener in onceListeners.reversed()) {
			if (listener.type != event.type) continue;
			listener.callback(event);
			onceListeners.remove(listener);
		}
	}

	@:expose
	static function notifyOnVideoChange(callback:VideoChangeFunc):Void {
		videoChange.push(callback);
	}

	@:expose
	static function removeFromVideoChange(callback:VideoChangeFunc):Void {
		videoChange.remove(callback);
	}

	public static function fireVideoChangeEvents(item:VideoItem):Void {
		for (callback in videoChange) {
			callback(item);
		}
	}

	@:expose
	static function notifyOnVideoRemove(callback:VideoChangeFunc):Void {
		videoRemove.push(callback);
	}

	@:expose
	static function removeFromVideoRemove(callback:VideoChangeFunc):Void {
		videoRemove.remove(callback);
	}

	public static function fireVideoRemoveEvents(item:VideoItem):Void {
		for (callback in videoRemove) {
			callback(item);
		}
	}
}
