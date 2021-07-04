package client.players;

import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.ge;
import js.Browser.document;
import js.html.Element;

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

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final iframe = document.createDivElement();
		iframe.innerHTML = data.url;
		if (isValidIframe(iframe)) {
			callback({duration: 99 * 60 * 60});
		} else {
			callback({duration: 0});
		}
	}

	function isValidIframe(iframe:Element):Bool {
		if (iframe.children.length != 1) return false;
		return (iframe.firstChild.nodeName == "IFRAME" || iframe.firstChild.nodeName == "OBJECT");
	}

	public function loadVideo(item:VideoItem):Void {
		removeVideo();
		video = document.createDivElement();
		video.id = "videoplayer";
		video.innerHTML = item.url; // actually data
		if (!isValidIframe(video)) {
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

	public function isVideoLoaded():Bool {
		return video != null;
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
