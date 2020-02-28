package client.players;

import js.html.Element;
import js.Browser.document;
import client.Main.ge;
import js.youtube.Youtube as YtInit;
import js.youtube.YoutubePlayer;
import Types.VideoItem;
using StringTools;

class Youtube implements IPlayer {

	static final matchId = ~/v=([A-z0-9_-]+)/;
	static final matchShort = ~/youtu.be\/([A-z0-9_-]+)/;
	static final matchEmbed = ~/embed\/([A-z0-9_-]+)/;
	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var video:Element;
	var youtube:YoutubePlayer;
	var isLoaded = false;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public static function isYoutube(url:String):Bool {
		if (url.contains("youtu.be/")) {
			return matchShort.match(url);
		}
		if (url.contains("youtube.com/embed/")) {
			return matchEmbed.match(url);
		}
		if (!url.contains("youtube.com/")) return false;
		return matchId.match(url);
	}

	function extractVideoId(url:String):String {
		if (url.contains("youtu.be/")) {
			matchShort.match(url);
			return matchShort.matched(1);
		}
		if (url.contains("youtube.com/embed/")) {
			matchEmbed.match(url);
			return matchEmbed.matched(1);
		}
		matchId.match(url);
		return matchId.matched(1);
	}

	public function getRemoteDuration(url:String, callback:(duration:Float)->Void):Void {
		if (!YtInit.isLoadedAPI) {
			YtInit.init(() -> getRemoteDuration(url, callback));
			return;
		}
		final video = document.createDivElement();
		video.id = "temp-videoplayer";
		Utils.prepend(playerEl, video);
		youtube = new YoutubePlayer(video.id, {
			videoId: extractVideoId(url),
			playerVars: {
				modestbranding: 1,
				rel: 0,
				showinfo: 0
			},
			events: {
				onReady: e -> {
					if (playerEl.contains(video)) playerEl.removeChild(video);
					callback(youtube.getDuration());
				},
				onError: e -> {
					trace('Error ${e.data}');
					if (playerEl.contains(video)) playerEl.removeChild(video);
					callback(0);
				}
			}
		});
	}

	public function loadVideo(item:VideoItem):Void {
		if (!YtInit.isLoadedAPI) {
			YtInit.init(() -> loadVideo(item));
			return;
		}
		video = document.createDivElement();
		video.id = "videoplayer";
		playerEl.appendChild(video);

		youtube = new YoutubePlayer(video.id, {
			videoId: extractVideoId(item.url),
			playerVars: {
				autoplay: 1,
				modestbranding: 1,
				rel: 0,
				showinfo: 0,
			},
			events: {
				// onReady: e -> player.onCanBePlayed(),
				onStateChange: e -> {
					switch (e.data) {
						case UNSTARTED:
							isLoaded = true;
							player.onCanBePlayed();
						case ENDED:
						case PLAYING:
							player.onPlay();
						case PAUSED:
							player.onPause();
						case BUFFERING:
							player.onSetTime();
						case CUED:
					}
				}
			}
		});
	}

	public function removeVideo():Void {
		if (video == null) return;
		playerEl.removeChild(video);
		video = null;
	}

	public function play():Void {
		if (!isLoaded) return;
		youtube.playVideo();
	}

	public function pause():Void {
		if (!isLoaded) return;
		youtube.pauseVideo();
	}

	public function getTime():Float {
		if (!isLoaded) return 0;
		return youtube.getCurrentTime();
	}

	public function setTime(time:Float):Void {
		if (!isLoaded) return;
		youtube.seekTo((time : Any), true);
	}

}
