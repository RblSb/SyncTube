package client.players;

import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.ge;
import haxe.Timer;
import js.Browser.document;
import js.hlsjs.Hls;
import js.html.Element;
import js.html.InputElement;
import js.html.VideoElement;

using StringTools;

class Raw implements IPlayer {
	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	final titleInput:InputElement = cast ge("#mediatitle");
	final subsInput:InputElement = cast ge("#subsurl");
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

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final url = data.url;
		final decodedUrl = url.urlDecode();

		final optTitle = titleInput.value.trim();
		var title = decodedUrl.substr(decodedUrl.lastIndexOf("/") + 1);
		final isNameMatched = matchName.match(title);
		if (optTitle != "") title = optTitle;
		else if (isNameMatched) title = matchName.matched(1);
		else title = Lang.get("rawVideo");

		var isHls = false;
		if (isNameMatched) isHls = matchName.matched(2).contains("m3u8");
		else isHls = title.endsWith("m3u8");
		if (isHls && !isHlsLoaded) {
			loadHlsPlugin(() -> getVideoData(data, callback));
			return;
		}

		titleInput.value = "";
		final subs = subsInput.value.trim();
		subsInput.value = "";
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
				title: title,
				subs: subs
			});
		}
		Utils.prepend(playerEl, video);
		if (isHls) initHlsSource(video, url);
	}

	function loadHlsPlugin(callback:() -> Void):Void {
		final url = "https://cdn.jsdelivr.net/npm/hls.js@latest";
		JsApi.addScriptToHead(url, () -> {
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
		final isHls = item.url.contains("m3u8") || item.title.endsWith("m3u8");
		if (isHls && !isHlsLoaded) {
			loadHlsPlugin(() -> loadVideo(item));
			return;
		}
		if (video != null) {
			video.src = url;
			for (element in video.children) {
				if (element.nodeName != "TRACK") continue;
				element.remove();
			}
		} else {
			video = document.createVideoElement();
			video.id = "videoplayer";
			video.setAttribute("playsinline", "");
			video.src = url;
			video.oncanplaythrough = player.onCanBePlayed;
			video.onseeking = player.onSetTime;
			video.onplay = e -> {
				playAllowed = true;
				player.onPlay();
			}
			video.onpause = player.onPause;
			video.onratechange = player.onRateChange;
			playerEl.appendChild(video);
		}
		if (isHls) initHlsSource(video, url);
		restartControlsHider();
		RawSubs.loadSubs(item, video);
	}

	function restartControlsHider():Void {
		video.controls = true;
		if (Utils.isTouch()) return;
		if (controlsHider != null) controlsHider.stop();
		controlsHider = Timer.delay(() -> {
			if (video == null) return;
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
