package client.players;

import Types.VideoData;
import Types.VideoDataRequest;
import haxe.DynamicAccess;
import haxe.Http;
import haxe.Json;

class Streamable extends Raw {
	final matchStreamable = ~/streamable\.com\/(.+)/g;
	final matchBadStreamableId = ~/[^0-9A-z-_]/g;

	override function isSupportedLink(url:String):Bool {
		if (!matchStreamable.match(url)) return false;
		final id = matchStreamable.matched(1);
		if (matchBadStreamableId.match(id)) return false;
		return true;
	}

	override function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void) {
		getStreamableVideoData(data.url, info -> {
			if (info == null) {
				callback({duration: 0});
				return;
			}

			getRawVideoData({url: info.url, atEnd: data.atEnd}, data -> {
				// set new url instead of using input one to load video
				data.url = info.url;
				data.title = info.title;
				callback(data);
			});
		});
	}

	function getRawVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		super.getVideoData(data, callback);
	}

	function getStreamableVideoData(url:String, callback:(info:Null<{url:String, title:String}>) -> Void):Void {
		if (!matchStreamable.match(url)) {
			callback(null);
			return;
		}
		final id = matchStreamable.matched(1);
		final http = new Http('https://api.streamable.com/videos/$id');
		http.onData = text -> {
			try {
				final json:{title:String, ?files:DynamicAccess<Dynamic>} = Json.parse(text);
				final files = json?.files;
				var item = files["mp4"];
				if (item == null) {
					final key = files.keys()[0];
					item = files[key];
				}
				callback({
					url: item.url,
					title: json.title
				});
			} catch (e) {
				callback(null);
			}
		}
		http.request();
	}
}
