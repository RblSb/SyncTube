package client.players;

import Types.VideoItem;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import js.Browser.document;
import js.Browser.window;
import js.html.VideoElement;

using StringTools;

private typedef Duration = {
	h:Int,
	m:Int,
	s:Int,
	ms:Int
}

class RawSubs {
	public static function loadSubs(item:VideoItem, video:VideoElement):Void {
		final ext = PathTools.urlExtension(item.subs);
		// do not load subs if there is custom plugin
		if (JsApi.hasSubtitleSupport(ext)) return;
		final url = '/proxy?url=${encodeURI(item.subs)}';

		switch ext {
			case "ass":
			case "srt":
				parseSrt(video, url);
			case "vtt":
				onParsed(video, "VTT subtitles", url);
				// parseVtt(video, url);
		}
	}

	static function parseSrt(video:VideoElement, url:String):Void {
		window.fetch(url).then(response -> {
			return response.text();
		}).then(text -> {
			final subs:Array<{
				counter:String,
				time:String,
				text:String
			}> = [];
			final blocks = text.replace("\r\n", "\n").split("\n\n");
			for (block in blocks) {
				final lines = block.split("\n");
				if (lines.length < 3) continue;
				final textLines = [
					for (i in 2...lines.length) lines[i]
				];
				subs.push({
					counter: lines[0],
					time: lines[1].replace(",", "."),
					text: textLines.join("\n")
				});
			}
			var data = "WEBVTT\n\n";
			for (sub in subs) {
				data += '${sub.counter}\n';
				data += '${sub.time}\n';
				data += '${sub.text}\n\n';
			}
			trace(data);
			final textBase64 = "data:text/plain;base64,";
			final url = textBase64 + Base64.encode(Bytes.ofString(data));
			onParsed(video, "SRT subtitles", url);
		});
	}

	// function saveSubs() {
	// 	final options = [
	// 		for (i in 0...subsSelect.options.length)
	// 			subsSelect.item(i)
	// 	];
	// 	var inputId = (cast el("#id-offset") : InputElement).value;
	// 	var id = Std.parseInt(inputId);
	// 	if (id == null) id = 1;
	// 	final data:Array<String> = options.map(element -> {
	// 		final value = element.textContent;
	// 		final firstTime = Std.parseFloat(value.split("|")[0]);
	// 		final secondTime = Std.parseFloat(value.split("|")[1]);
	// 		// 00:00:00,498 --> 00:00:02,827
	// 		var time = '$id\n';
	// 		time += srvTimeFormat(stringDuration(firstTime));
	// 		time += " --> ";
	// 		time += srvTimeFormat(stringDuration(secondTime));
	// 		time += '\ntext$id\n';
	// 		id++;
	// 		return time;
	// 	});
	// 	final data = data.join("\n");
	// 	Utils.saveFile("subs.srv", TextPlain, data);
	// }

	function stringDuration(seconds:Float):Duration {
		final h = Std.int(seconds / 60 / 60);
		final m = Std.int(seconds / 60) - h * 60;
		final s = Std.int(seconds % 60);
		final ms = Std.int((seconds - Std.int(seconds)) * 1000);
		return {
			h: h,
			m: m,
			s: s,
			ms: ms
		}
	}

	function srvTimeFormat(time:Duration):String {
		final h = '${time.h}'.lpad("0", 2);
		final m = '${time.m}'.lpad("0", 2);
		final s = '${time.s}'.lpad("0", 2);
		final ms = '${time.ms}'.rpad("0", 3);
		return '$h:$m:$s,$ms';
	}

	static function parseVtt(video:VideoElement, url:String):Void {
		window.fetch(url).then(response -> response.text()).then(data -> {
			final textBase64 = "data:text/plain;base64,";
			final url = textBase64 + Base64.encode(Bytes.ofString(data));
			onParsed(video, "VTT subtitles", url);
		});
	}

	static function onParsed(video:VideoElement, name:String, dataUrl:String) {
		final trackEl = document.createTrackElement();
		trackEl.label = name;
		trackEl.kind = "subtitles";
		trackEl.src = dataUrl;
		trackEl.default_ = true;
		final track = trackEl.track;
		track.mode = SHOWING;
		video.appendChild(trackEl);
	}

	static function encodeURI(data:String):String {
		return js.Syntax.code("encodeURI({0})", data);
	}
}
