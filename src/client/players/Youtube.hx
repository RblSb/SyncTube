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
	static final matchPlaylist = ~/youtube\.com.*list=([A-z0-9_-]+)/;
	static final videosUrl = "https://www.googleapis.com/youtube/v3/videos";
	static final playlistUrl = "https://www.googleapis.com/youtube/v3/playlistItems";
	static final urlTitleDuration = "?part=snippet,contentDetails&fields=items(snippet/title,contentDetails/duration)";
	static final urlVideoId = "?part=snippet&fields=items(snippet/resourceId/videoId)";
	static var apiKey:String;
	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var video:Element;
	var youtube:YoutubePlayer;
	var isLoaded = false;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
		apiKey = main.getYoutubeApiKey();
	}

	public static function isYoutube(url:String):Bool {
		return extractVideoId(url) != "" || extractPlaylistId(url) != "";
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

	static function extractPlaylistId(url:String):String {
		if (!matchPlaylist.match(url)) return "";
		return matchPlaylist.matched(1);
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
		var id = extractVideoId(url);
		if (id == "") {
			getPlaylistVideoData(url, callback);
			return;
		}
		final dataUrl = '$videosUrl$urlTitleDuration&id=$id&key=$apiKey';
		final http = new Http(dataUrl);
		http.onData = data -> {
			final json = Json.parse(data);
			if (json.error != null) {
				youtubeApiError(json.error);
				getRemoteDataFallback(url, callback);
				return;
			}
			final items:Array<Dynamic> = json.items;
			if (items == null || items.length == 0) {
				callback({duration: 0});
				return;
			}
			for (item in items) {
				final title:String = item.snippet.title;
				final duration:String = item.contentDetails.duration;
				// TODO duration is PT0S for streams
				callback({
					duration: convertTime(duration),
					title: title,
					url: url
				});
			}
		}
		http.onError = msg -> getRemoteDataFallback(url, callback);
		http.request();
	}

	function getPlaylistVideoData(url:String, callback:(data:VideoData)->Void):Void {
		final id = extractPlaylistId(url);
		final dataUrl = '$playlistUrl$urlVideoId&maxResults=50&playlistId=$id&key=$apiKey';
		final http = new Http(dataUrl);
		http.onData = data -> {
			final json = Json.parse(data);
			if (json.error != null) {
				youtubeApiError(json.error);
				callback({duration: 0});
				return;
			}
			final items:Array<Dynamic> = json.items;
			if (items == null || items.length == 0) {
				callback({duration: 0});
				return;
			}
			function loadNextItem():Void {
				final item = items.shift();
				final id:String = item.snippet.resourceId.videoId;
				getVideoData('youtu.be/$id', data -> {
					callback(data);
					if (items.length > 0) loadNextItem();
				});
			}
			loadNextItem();
		}
		http.onError = msg -> callback({duration: 0});
		http.request();
	}

	function youtubeApiError(error:Dynamic):Void {
		final code:Int = error.code;
		final msg:String = error.message;
		main.serverMessage(4, 'Error $code: $msg', false);
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
				},
				onPlaybackRateChange: e -> {
					player.onRateChange();
				},
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

	public function getPlaybackRate():Float {
		if (!isLoaded) return 1;
		return youtube.getPlaybackRate();
	}

	public function setPlaybackRate(rate:Float):Void {
		if (!isLoaded) return;
		youtube.setPlaybackRate(rate);
	}

}
