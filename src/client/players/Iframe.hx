package client.players;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.getEl;
import js.Browser.document;
import js.Browser;
import js.html.DOMParser;
import js.html.Element;
import js.html.SupportedType;

class Iframe implements IPlayer {
	static final matchTwitchChannel = ~/^(?:https?:\/\/)?(?:www\.|m\.)?twitch\.tv\/([A-Za-z0-9_]+)\/?$/i;

	final main:Main;
	final player:Player;
	final playerEl:Element = getEl("#ytapiplayer");
	var video:Element;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function getPlayerType():PlayerType {
		return IframeType;
	}

	public static function extractTwitchChannel(url:String):String {
		url = url.trim();
		if (!matchTwitchChannel.match(url)) return "";
		final channel = matchTwitchChannel.matched(1);
		return channel;
	}

	public static function extractIframeSrc(html:String):String {
		try {
			final doc = new DOMParser().parseFromString(html, SupportedType.TEXT_HTML);
			final el = doc.body.firstElementChild;
			if (el != null && el.nodeName == "IFRAME") {
				final src = el.getAttribute("src");
				if (src != null && ~/^(?:https?:)?\/\//i.match(src)) return src;
			}
		} catch (e:Dynamic) {}
		return "";
	}

	public function isSupportedLink(url:String):Bool {
		final trimmed = url.trim();
		if (extractTwitchChannel(trimmed).length > 0) return true;
		if (trimmed.startsWith("<iframe")) return true;
		return false;
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final rawUrl = data.url.trim();
		final channel = extractTwitchChannel(rawUrl);
		if (channel.length > 0) {
			final iframeStr = '<iframe src="https://player.twitch.tv/?channel=$channel&parent=www.example.com" frameborder="0" allowfullscreen="true" scrolling="no" height="378" width="620"></iframe>';
			callback({
				duration: 99 * 60 * 60,
				title: 'Twitch: $channel',
				url: iframeStr
			});
			return;
		}

		final src = extractIframeSrc(rawUrl);
		if (src.length > 0) {
			callback({
				duration: 99 * 60 * 60,
				title: "Iframe media",
				url: '<iframe src="$src"></iframe>'
			});
		} else {
			callback({duration: 0});
		}
	}

	public function loadVideo(item:VideoItem):Void {
		removeVideo();
		var src = extractIframeSrc(item.url);
		if (src.length == 0) return;

		if (src.contains("player.twitch.tv")) {
			final hostname = Browser.location.hostname;
			src = src.replace("parent=www.example.com", 'parent=$hostname');
			if (!~/[A-z]/.match(hostname)) {
				Main.instance.serverMessage(
					'Twitch player blocks access from ips, please use SyncTube from any domain for it.
You can register some on <a href="https://nya.pub" target="_blank">nya.pub</a>.',
					false
				);
			}
		}

		final iframe = document.createIFrameElement();
		iframe.id = "videoplayer";
		iframe.src = src;
		iframe.allowFullscreen = true;
		iframe.setAttribute("allow", "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture");

		video = document.createDivElement();
		video.classList.add("videoplayerIframeParent");
		video.appendChild(iframe);
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

	public function isPaused():Bool {
		return false;
	}

	public function getTime():Float {
		return 0;
	}

	public function setTime(time:Float):Void {}

	public function getPlaybackRate():Float {
		return 1;
	}

	public function setPlaybackRate(rate:Float):Void {}

	public function getVolume():Float {
		return 1;
	}

	public function setVolume(volume:Float) {}

	public function unmute():Void {}
}
