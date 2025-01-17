package client.players;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.ge;
import haxe.Constraints.Function;
import js.Browser.document;
import js.html.Element;
import js.html.Node;

private enum abstract VkPlayerState(String) {
	var Uninited = "uninited";
	var Unstarted = "unstarted";
	var Playing = "playing";
	var Paused = "paused";
	var Ended = "ended";
	var Error = "error";
}

private extern class VkPlayer {
	function play():Void;
	function pause():Void;
	function seek(time:Float):Void;
	function seekLive():Void;
	function setVolume(volume:Float):Void;
	function getVolume():Float;
	function getCurrentTime():Float;
	function getDuration():Int;
	function getQuality():Int; // 480, etc
	function mute():Void;
	function unmute():Void;
	function isMuted():Bool;
	function getState():VkPlayerState;
	function on(event:String, listener:Function):Void;
	function off(event:String, listener:Function):Void;
	function destroy():Void;
}

class Vk implements IPlayer {
	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var video:Element;
	var vkPlayer:VkPlayer;
	var isLoaded = false;
	var isApiLoaded = false;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function getPlayerType():PlayerType {
		return VkType;
	}

	final matchVk = ~/(vk.com\/video|vkvideo)/g;
	final matchIds = ~/video(-?[0-9]+)_([0-9]+)/g;

	public function isSupportedLink(url:String):Bool {
		return matchVk.match(url) && getVideoIds(url) != null;
	}

	function getVideoIds(url:String):Null<{oid:String, id:String}> {
		if (!matchIds.match(url)) {
			trace("Cannot extract /video-oid_id values from url:");
			return null;
		}
		final oid = matchIds.matched(1);
		final id = matchIds.matched(2);
		return {oid: oid, id: id};
	}

	function loadApi(callback:() -> Void):Void {
		final url = "https://vk.com/js/api/videoplayer.js";
		JsApi.addScriptToHead(url, () -> {
			isApiLoaded = true;
			callback();
		});
	}

	function createVkPlayer(iframe:Node):VkPlayer {
		return untyped VK.VideoPlayer(iframe);
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		if (!isApiLoaded) {
			loadApi(() -> {
				getVideoData(data, callback);
			});
			return;
		}
		final url = data.url;

		final video = document.createDivElement();
		video.id = "temp-videoplayer";
		final ids = getVideoIds(url);
		if (ids == null) {
			callback({duration: 0});
			return;
		}
		final oid = ids.oid;
		final id = ids.id;
		video.innerHTML = '
			<iframe src="https://vk.com/video_ext.php?oid=$oid&id=$id&hd=1&js_api=1"
				allow="autoplay; encrypted-media; fullscreen; picture-in-picture;"
				frameborder="0" allowfullscreen>
			</iframe>
		'.trim();
		Utils.prepend(playerEl, video);
		final tempVkPlayer = createVkPlayer(video.firstChild);
		tempVkPlayer.on("inited", () -> {
			callback({
				duration: tempVkPlayer.getDuration(),
				title: "VK media",
				url: url
			});
			tempVkPlayer.destroy();
			if (playerEl.contains(video)) playerEl.removeChild(video);
		});
	}

	public function loadVideo(item:VideoItem):Void {
		if (!isApiLoaded) {
			loadApi(() -> {
				loadVideo(item);
			});
			return;
		}

		removeVideo();

		final ids = getVideoIds(item.url) ?? return;
		video = document.createDivElement();
		video.id = "videoplayer";
		final oid = ids.oid;
		final id = ids.id;
		video.innerHTML = '
			<iframe src="https://vk.com/video_ext.php?oid=$oid&id=$id&hd=4&js_api=1"
				allow="autoplay; encrypted-media; fullscreen; picture-in-picture;"
				frameborder="0" allowfullscreen>
			</iframe>
		'.trim();
		playerEl.appendChild(video);
		vkPlayer = createVkPlayer(video.firstChild);
		vkPlayer.on("inited", () -> {
			if (!main.isAutoplayAllowed()) vkPlayer.mute();
			isLoaded = true;
			vkPlayer.pause();
			setTime(0);
			player.onCanBePlayed();
		});

		vkPlayer.on("started", () -> {
			player.onPlay();
		});
		vkPlayer.on("resumed", () -> {
			player.onPlay();
		});
		vkPlayer.on("paused", () -> {
			player.onPause();
		});
		vkPlayer.on("error", e -> {
			trace('Error $e');
		});
		var prevTime = 0.0;
		vkPlayer.on("timeupdate", (e:{time:Float}) -> {
			final diff = Math.abs(prevTime - e.time);
			prevTime = e.time;
			if (diff > 1) player.onSetTime();
		});
	}

	public function removeVideo():Void {
		if (video == null) return;
		isLoaded = false;
		vkPlayer.destroy();
		vkPlayer = null;
		if (playerEl.contains(video)) playerEl.removeChild(video);
		video = null;
	}

	public function isVideoLoaded():Bool {
		return isLoaded;
	}

	public function play():Void {
		vkPlayer.play();
	}

	public function pause():Void {
		vkPlayer.pause();
	}

	public function isPaused():Bool {
		final state = vkPlayer.getState();
		return state == Unstarted || state == Paused;
	}

	public function getTime():Float {
		return vkPlayer.getCurrentTime();
	}

	public function setTime(time:Float):Void {
		vkPlayer.seek(time);
	}

	public function getPlaybackRate():Float {
		return 1;
	}

	public function setPlaybackRate(rate:Float):Void {}

	public function getVolume():Float {
		if (vkPlayer.isMuted()) return 0;
		return vkPlayer.getVolume();
	}

	public function setVolume(volume:Float):Void {
		vkPlayer.setVolume(volume);
	}

	public function unmute():Void {
		vkPlayer.unmute();
	}
}
