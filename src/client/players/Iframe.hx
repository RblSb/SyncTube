package client.players;

import haxe.Timer;
import js.html.Element;
import js.html.VideoElement;
import js.Browser.document;
import client.Main.ge;
import Types.VideoData;
import Types.VideoItem;

class Iframe implements IPlayer {

	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var video:Element;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function isSupportedLink(url:String):Bool {
		return true;
	}

	public function getVideoData(url:String, callback:(data:VideoData)->Void):Void {
		callback({
			duration: 99 * 60 * 60,
			title: "Custom Media"
		});
	}

	public function loadVideo(item:VideoItem):Void {
		removeVideo();
		video = document.createDivElement();
		video.id = "videoplayer";
		video.innerHTML = item.url;
		if (video.firstChild.nodeName != "IFRAME"
			&& video.firstChild.nodeName != "OBJECT") {
			// TODO move to getVideoData too
			video = null;
			return;
		}
		if (video.firstChild.nodeName == "IFRAME") {
			video.setAttribute("sandbox", "allow-scripts");
		}
		playerEl.appendChild(video);
	}

	public function removeVideo():Void {
		if (video == null) return;
		playerEl.removeChild(video);
		video = null;
	}

	public function play():Void {}

	public function pause():Void {}

	public function getTime():Float {
		return 0;
	}

	public function setTime(time:Float):Void {}

	public function getPlaybackRate():Float {
		return 1;
	}

	public function setPlaybackRate(rate:Float):Void {}

}
