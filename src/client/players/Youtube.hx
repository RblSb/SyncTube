package client.players;

import haxe.Json;
import haxe.Http;
import js.html.Element;
import js.Browser.document;
import client.Main.ge;
import js.youtube.Youtube as YtInit;
import js.youtube.YoutubePlayer;
import Types.VideoData;
import Types.VideoItem;
using StringTools;

class Youtube implements IPlayer {

	static final matchId = ~/v=([A-z0-9_-]+)/;
	static final matchShort = ~/youtu.be\/([A-z0-9_-]+)/;
	static final matchEmbed = ~/embed\/([A-z0-9_-]+)/;
	static final apiUrl = "https://www.googleapis.com/youtube/v3/videos";
	static final urlTitleDuration = "?part=snippet,contentDetails&fields=items(snippet/title,contentDetails/duration)";
	static final apiKey = "AIzaSyDTk1OPRI9cDkAK_BKsBcv10DQCHse-QaA";
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
		return extractVideoId(url) != "";
	}

	static function extractVideoId(url:String):String {
		if (url.contains("youtu.be/")) {
			matchShort.match(url);
			return matchShort.matched(1);
		}
		if (url.contains("youtube.com/embed/")) {
			matchEmbed.match(url);
			return matchEmbed.matched(1);
		}
		if (!matchId.match(url)) return "";
		return matchId.matched(1);
	}

	final matchHours = ~/([0-9]+)H/;
	final matchMinutes = ~/([0-9]+)M/;
	final matchSeconds = ~/([0-9]+)S/;

	function convertTime(duration:String):Float {
		var total = 0;
		final hours = matchHours.match(duration);
		final minutes = matchMinutes.match(duration);
		final seconds = matchSeconds.match(duration);
		if (hours) total += Std.parseInt(matchHours.matched(1)) * 3600;
		if (minutes) total += Std.parseInt(matchMinutes.matched(1)) * 60;
		if (seconds) total += Std.parseInt(matchSeconds.matched(1));
		return total;
	}

	public function getVideoData(url:String, callback:(data:VideoData)->Void):Void {
		final id = extractVideoId(url);
		final url = '$apiUrl$urlTitleDuration&id=$id&key=$apiKey';
		final http = new Http(url);
		http.onData = data -> {
			final json = Json.parse(data);
			if (json.error != null) {
				getRemoteDataFallback(url, callback);
				return;
			}
			final item = json.items[0];
			if (item == null) {
				callback({duration: 0});
				return;
			}
			final title:String = item.snippet.title;
			final duration:String = item.contentDetails.duration;
			// TODO duration is PT0S for streams
			callback({
				duration: convertTime(duration),
				title: title
			});
		}
		http.onError = msg -> getRemoteDataFallback(url, callback);
		http.request();
	}

	function getRemoteDataFallback(url:String, callback:(data:VideoData)->Void):Void {
		if (!YtInit.isLoadedAPI) {
			YtInit.init(() -> getRemoteDataFallback(url, callback));
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
					callback({
						duration: youtube.getDuration()
					});
				},
				onError: e -> {
					// TODO message error codes
					trace('Error ${e.data}');
					if (playerEl.contains(video)) playerEl.removeChild(video);
					callback({duration: 0});
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
				start: 0
			},
			events: {
				onReady: e -> isLoaded = true,
				onStateChange: e -> {
					switch (e.data) {
						case UNSTARTED:
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
		if (playerEl.contains(video)) playerEl.removeChild(video);
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
		youtube.seekTo(time, true);
	}

}
