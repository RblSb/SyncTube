package client.players;

import haxe.Timer;
import js.html.Element;
import js.html.VideoElement;
import js.Browser.document;
import client.Main.ge;
import Types.VideoData;
import Types.VideoItem;

class Raw implements IPlayer {

	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var controlsHider:Timer;
	var playAllowed = true;
	var video:VideoElement;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function isSupportedLink(url:String):Bool {
		return true;
	}

	public function getVideoData(url:String, callback:(data:VideoData)->Void):Void {
		var title = url.substr(url.lastIndexOf('/') + 1);
		final matchName = ~/^(.+)\./;
		if (matchName.match(title)) title = matchName.matched(1);
		else title = Lang.get("rawVideo");

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
	}

	public function loadVideo(item:VideoItem):Void {
		final url = main.tryLocalIp(item.url);
		if (video != null) {
			video.src = url;
			return;
		}
		video = document.createVideoElement();
		video.id = "videoplayer";
		video.src = url;
		video.controls = true;
		if (controlsHider != null) controlsHider.stop();
		if (!Utils.isTouch()) controlsHider = Timer.delay(() -> {
			video.controls = false;
		}, 3000);
		video.onmousemove = e -> {
			if (controlsHider != null) controlsHider.stop();
			video.controls = true;
			video.onmousemove = null;
		}
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

	public function removeVideo():Void {
		if (video == null) return;
		playerEl.removeChild(video);
		video = null;
	}

	public function play():Void {
		if (video == null) return;
		if (!playAllowed) return;
		final promise = video.play();
		if (promise == null) return;
		promise.catchError(error -> {
			// Do not try to play video anymore or Chromium will hide play button
			playAllowed = false;
		});
	}

	public function pause():Void {
		if (video == null) return;
		video.pause();
	}

	public function getTime():Float {
		if (video == null) return 0;
		return video.currentTime;
	}

	public function setTime(time:Float):Void {
		if (video == null) return;
		video.currentTime = time;
	}

	public function getPlaybackRate():Float {
		if (video == null) return 1;
		return video.playbackRate;
	}

	public function setPlaybackRate(rate:Float):Void {
		if (video == null) return;
		video.playbackRate = rate;
	}

}
