package client.players;

import js.hlsjs.Hls;
import haxe.Timer;
import js.html.Element;
import js.html.VideoElement;
import js.Browser.document;
import client.Main.ge;
import Types.VideoData;
import Types.VideoItem;
using StringTools;

class Raw implements IPlayer {

	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	final matchName = ~/^(.+)\.(.+)/;
	var controlsHider:Timer;
	var playAllowed = true;
	var video:VideoElement;
	var isHlsLoaded = false;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function isSupportedLink(url:String):Bool {
		return true;
	}

	public function getVideoData(url:String, callback:(data:VideoData)->Void):Void {
		final decodedUrl = url.urlDecode();
		var title = decodedUrl.substr(decodedUrl.lastIndexOf("/") + 1);
		final isNameMatched = matchName.match(title);
		if (isNameMatched) title = matchName.matched(1);
		else title = Lang.get("rawVideo");
		var isHls = false;
		if (isNameMatched) {
			isHls = matchName.matched(2).contains("m3u8");
			if (isHls && !isHlsLoaded) {
				loadHlsPlugin(() -> getVideoData(url, callback));
				return;
			}
		}

		final video = document.createVideoElement();
		video.src = url;
		video.onerror = e -> {
			if (playerEl.contains(video)) playerEl.removeChild(video);
			callback({duration: 0});
		}
		video.onloadedmetadata = () -> {
			if (playerEl.contains(video)) playerEl.removeChild(video);
			callback({
				duration: video.duration,
				title: title
			});
		}
		Utils.prepend(playerEl, video);
		if (isHls) initHlsSource(video, url);
	}

	function loadHlsPlugin(callback:()->Void):Void {
		JsApi.addScriptToHead("https://cdn.jsdelivr.net/npm/hls.js@latest", () -> {
			isHlsLoaded = true;
			callback();
		});
	}

	function initHlsSource(video:VideoElement, url:String):Void {
		if (!Hls.isSupported()) return;
		final hls = new Hls();
		hls.loadSource(url);
		hls.attachMedia(video);
	}

	public function loadVideo(item:VideoItem):Void {
		final url = main.tryLocalIp(item.url);
		final isHls = item.url.contains("m3u8");
		if (isHls && !isHlsLoaded) {
			loadHlsPlugin(() -> loadVideo(item));
			return;
		}
		if (video != null) {
			video.src = url;
			if (isHls) initHlsSource(video, url);
			restartControlsHider();
			return;
		}
		video = document.createVideoElement();
		video.id = "videoplayer";
		video.src = url;
		restartControlsHider();
		video.oncanplaythrough = player.onCanBePlayed;
		video.onseeking = player.onSetTime;
		video.onplay = e -> {
			playAllowed = true;
			player.onPlay();
		}
		video.onpause = player.onPause;
		video.onratechange = player.onRateChange;
		playerEl.appendChild(video);
		if (isHls) initHlsSource(video, url);
	}

	function restartControlsHider():Void {
		video.controls = true;
		if (Utils.isTouch()) return;
		if (controlsHider != null) controlsHider.stop();
		controlsHider = Timer.delay(() -> {
			video.controls = false;
		}, 3000);
		video.onmousemove = e -> {
			if (controlsHider != null) controlsHider.stop();
			video.controls = true;
			video.onmousemove = null;
		}
	}

	public function removeVideo():Void {
		if (video == null) return;
		video.pause();
		video.removeAttribute("src");
		video.load();
		playerEl.removeChild(video);
		video = null;
	}

	public function isVideoLoaded():Bool {
		return video != null;
	}

	public function play():Void {
		if (!playAllowed) return;
		final promise = video.play();
		if (promise == null) return;
		promise.catchError(error -> {
			// Do not try to play video anymore or Chromium will hide play button
			playAllowed = false;
		});
	}

	public function pause():Void {
		video.pause();
	}

	public function getTime():Float {
		return video.currentTime;
	}

	public function setTime(time:Float):Void {
		video.currentTime = time;
	}

	public function getPlaybackRate():Float {
		return video.playbackRate;
	}

	public function setPlaybackRate(rate:Float):Void {
		video.playbackRate = rate;
	}

}
