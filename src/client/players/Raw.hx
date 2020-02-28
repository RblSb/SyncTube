package client.players;

import haxe.Timer;
import js.html.Element;
import js.html.VideoElement;
import js.Browser.document;
import client.Main.ge;
import Types.VideoItem;

class Raw implements IPlayer {

	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var video:VideoElement;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function getRemoteDuration(src:String, callback:(duration:Float)->Void):Void {
		final video = document.createVideoElement();
		video.src = src;
		// TODO catch errors on AddVideo and getRemoteVideoDuration
		video.onerror = e -> {
			if (playerEl.contains(video)) playerEl.removeChild(video);
			callback(0);
		}
		video.onloadedmetadata = () -> {
			if (playerEl.contains(video)) playerEl.removeChild(video);
			callback(video.duration);
		}
		Utils.prepend(playerEl, video);
	}

	public function loadVideo(item:VideoItem):Void {
		video = document.createVideoElement();
		video.id = "videoplayer";
		final url = main.tryLocalIp(item.url);
		video.src = url;
		video.controls = true;
		final isTouch = untyped __js__("'ontouchstart' in window");
		if (!isTouch) Timer.delay(() -> {
			video.controls = false;
			video.onmouseover = e -> {
				video.controls = true;
				video.onmouseover = null;
				video.onmousemove = null;
			}
			video.onmousemove = video.onmouseover;
		}, 3000);
		video.oncanplaythrough = player.onCanBePlayed;
		video.onseeking = player.onSetTime;
		video.onplay = player.onPlay;
		video.onpause = player.onPause;
		playerEl.appendChild(video);
		video.pause();
	}

	public function removeVideo():Void {
		if (video == null) return;
		playerEl.removeChild(video);
		video = null;
	}

	public function play():Void {
		if (video == null) return;
		video.play();
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

}
