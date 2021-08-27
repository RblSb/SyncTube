package client.players;

import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.ge;
import haxe.Http;
import haxe.Json;
import js.Browser.document;
import js.html.Element;
import js.youtube.Youtube as YtInit;
import js.youtube.YoutubePlayer;

using StringTools;

class Youtube implements IPlayer {
	final matchId = ~/youtube\.com.*v=([A-z0-9_-]+)/;
	final matchShort = ~/youtu\.be\/([A-z0-9_-]+)/;
	final matchEmbed = ~/youtube\.com\/embed\/([A-z0-9_-]+)/;
	final matchPlaylist = ~/youtube\.com.*list=([A-z0-9_-]+)/;
	final videosUrl = "https://www.googleapis.com/youtube/v3/videos";
	final playlistUrl = "https://www.googleapis.com/youtube/v3/playlistItems";
	final urlTitleDuration = "?part=snippet,contentDetails&fields=items(snippet/title,contentDetails/duration)";
	final urlVideoId = "?part=snippet&fields=nextPageToken,items(snippet/resourceId/videoId)";
	final main:Main;
	final player:Player;
	final playerEl:Element = ge("#ytapiplayer");
	var apiKey:String;
	var video:Element;
	var youtube:YoutubePlayer;
	var tempYoutube:YoutubePlayer;
	var isLoaded = false;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function isSupportedLink(url:String):Bool {
		return extractVideoId(url) != "" || extractPlaylistId(url) != "";
	}

	function extractVideoId(url:String):String {
		if (matchId.match(url)) {
			return matchId.matched(1);
		}
		if (matchShort.match(url)) {
			return matchShort.matched(1);
		}
		if (matchEmbed.match(url)) {
			return matchEmbed.matched(1);
		}
		return "";
	}

	function extractPlaylistId(url:String):String {
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

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final url = data.url;
		if (apiKey == null) apiKey = main.getYoutubeApiKey();
		final id = extractVideoId(url);
		if (id == "") {
			getPlaylistVideoData(data, callback);
			return;
		}
		final dataUrl = '$videosUrl$urlTitleDuration&id=$id&key=$apiKey';
		final http = new Http(dataUrl);
		http.onData = text -> {
			final json = Json.parse(text);
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
				final duration = convertTime(duration);
				// duration is PT0S for streams
				if (duration == 0) {
					callback({
						duration: 99 * 60 * 60,
						title: title,
						url: '<iframe src="https://www.youtube.com/embed/$id" frameborder="0"
							allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
							allowfullscreen></iframe>',
						isIframe: true
					});
					continue;
				}
				callback({
					duration: duration,
					title: title,
					url: url
				});
			}
		}
		http.onError = msg -> getRemoteDataFallback(url, callback);
		http.request();
	}

	function getPlaylistVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final url = data.url;
		final id = extractPlaylistId(url);
		var maxResults = main.getYoutubePlaylistLimit();
		final dataUrl = '$playlistUrl$urlVideoId&maxResults=$maxResults&playlistId=$id&key=$apiKey';

		function loadJson(url:String):Void {
			final http = new Http(url);
			http.onData = text -> {
				final json = Json.parse(text);
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
				if (!data.atEnd) main.sortItemsForQueueNext(items);
				function loadNextItem():Void {
					final item = items.shift();
					final id:String = item.snippet.resourceId.videoId;
					final obj = {
						url: 'https://youtu.be/$id',
						atEnd: data.atEnd
					};
					getVideoData(obj, data -> {
						callback(data);
						maxResults--;
						if (maxResults <= 0) return;
						if (items.length > 0) loadNextItem();
						else if (json.nextPageToken != null) {
							loadJson('$dataUrl&pageToken=${json.nextPageToken}');
						}
					});
				}
				loadNextItem();
			}
			http.onError = msg -> callback({duration: 0});
			http.request();
		}
		loadJson(dataUrl);
	}

	function youtubeApiError(error:Dynamic):Void {
		final code:Int = error.code;
		final msg:String = error.message;
		Main.serverMessage(4, 'Error $code: $msg', false);
	}

	function getRemoteDataFallback(url:String, callback:(data:VideoData) -> Void):Void {
		if (!YtInit.isLoadedAPI) {
			YtInit.init(() -> getRemoteDataFallback(url, callback));
			return;
		}
		final video = document.createDivElement();
		video.id = "temp-videoplayer";
		Utils.prepend(playerEl, video);
		tempYoutube = new YoutubePlayer(video.id, {
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
						duration: tempYoutube.getDuration()
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
		if (youtube != null) {
			youtube.loadVideoById({
				videoId: extractVideoId(item.url)
			});
			return;
		}
		isLoaded = false;
		video = document.createDivElement();
		video.id = "videoplayer";
		playerEl.appendChild(video);

		youtube = new YoutubePlayer(video.id, {
			videoId: extractVideoId(item.url),
			playerVars: {
				autoplay: 1,
				playsinline: 1,
				modestbranding: 1,
				rel: 0,
				showinfo: 0
			},
			events: {
				onReady: e -> {
					isLoaded = true;
					youtube.pauseVideo();
				},
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
				}
			}
		});
	}

	public function removeVideo():Void {
		if (video == null) return;
		isLoaded = false;
		youtube.destroy();
		youtube = null;
		if (playerEl.contains(video)) playerEl.removeChild(video);
		video = null;
	}

	public function isVideoLoaded():Bool {
		return isLoaded;
	}

	public function play():Void {
		youtube.playVideo();
	}

	public function pause():Void {
		youtube.pauseVideo();
	}

	public function getTime():Float {
		return youtube.getCurrentTime();
	}

	public function setTime(time:Float):Void {
		youtube.seekTo(time, true);
	}

	public function getPlaybackRate():Float {
		return youtube.getPlaybackRate();
	}

	public function setPlaybackRate(rate:Float):Void {
		youtube.setPlaybackRate(rate);
	}
}
