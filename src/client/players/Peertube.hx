package client.players;

import Types.VideoData;
import Types.VideoDataRequest;
import haxe.Http;
import haxe.Json;
import js.html.URL;

class Peertube extends Raw {
	final matchPeertube = ~/^pt:.+\/w\/(p\/)?([A-z0-9]+)/g;
	final matchOldPeertube = ~/^pt:.+\/videos\/watch\/([-A-z0-9]+)/g;

	override function isSupportedLink(url:String):Bool {
		return extractVideoId(url).length > 0;
	}

	public function extractVideoId(url:String):String {
		if (matchPeertube.match(url)) return matchPeertube.matched(2);
		if (matchOldPeertube.match(url)) return matchOldPeertube.matched(1);
		return "";
	}

	override function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void) {
		if (!isSupportedLink(data.url)) {
			getRawVideoData(data, callback);
			return;
		}
		getPeertubeVideoData(data.url, info -> {
			if (info == null) {
				callback({duration: 0});
				return;
			}
			getRawVideoData({url: info.url, atEnd: data.atEnd}, data -> {
				data.url = info.url;
				data.title = info.title;
				callback(data);
			});
		});
	}

	function getRawVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void) {
		super.getVideoData(data, callback);
	}

	function getPeertubeVideoData(url:String, callback:(info:Null<{url:String, title:String}>) -> Void) {
		final id = extractVideoId(url);

		url = url.replace("pt:", "");
		if (!url.startsWith("http")) url = 'https://$url';
		final urlObj = try {
			new URL(url);
		} catch (e) {
			trace(e);
			callback(null);
			return;
		}
		final host = urlObj.host;

		final isPlaylistItem = url.contains("/p/");
		if (isPlaylistItem) {
			final apiUrl = 'https://$host/api/v1/video-playlists/$id/videos';
			final http = new Http(apiUrl);
			http.onData = data -> {
				final json:{data:Array<Dynamic>, total:Int} = Json.parse(data);
				final arr = json.data;
				final pos = Std.parseInt(urlObj.searchParams.get("playlistPosition") ?? "1");
				final item:Dynamic = arr.find(item -> item.position == pos) ?? arr[0];
				final uuid:String = item.video?.uuid ?? {
					trace(item);
					callback(null);
					return;
				};
				getPeertubeVideoData('pt:https://$host/videos/watch/$uuid', callback);
			}
			http.onError = err -> {
				trace(err);
				callback(null);
			}
			http.request();
			return;
		}

		final apiUrl = 'https://$host/api/v1/videos/$id';
		final http = new Http(apiUrl);
		http.onData = data -> {
			try {
				final json = Json.parse(data);
				final title = json.name ?? "PeerTube video";
				final playlistUrl = getBestHlsPlaylistUrl(json);
				if (playlistUrl != null) {
					callback({
						url: playlistUrl,
						title: title
					});
					return;
				}

				final mp4Url = getBestMp4Url(json);
				if (mp4Url != null) {
					callback({
						url: mp4Url,
						title: title
					});
					return;
				}

				callback(null);
			} catch (e) {
				trace(e);
				callback(null);
			}
		}

		http.onError = err -> {
			trace(err);
			callback(null);
		}

		http.request();
	}

	function getBestHlsPlaylistUrl(json:Dynamic):Null<String> {
		final playlists:Array<Dynamic> = json.streamingPlaylists;
		if (playlists == null || playlists.length == 0) return null;
		return playlists[0].playlistUrl;
	}

	function getBestMp4Url(json:Dynamic):Null<String> {
		final files:Array<Dynamic> = json.files;
		if (files == null || files.length == 0) return null;
		files.sort(function(a, b) {
			return b.resolution.id - a.resolution.id;
		});
		return files[0].fileDownloadUrl;
	}
}
