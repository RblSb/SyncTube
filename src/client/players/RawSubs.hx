package client.players;

import Types.VideoItem;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import js.Browser.document;
import js.Browser.window;
import js.Browser;
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
		if (item.subs == null || item.subs.length == 0) return;
		final ext = PathTools.urlExtension(item.subs);
		// do not load subs if there is custom plugin
		if (JsApi.hasSubtitleSupport(ext)) return;
		var url = encodeURI(item.subs);
		if (!url.startsWith("/")) {
			final protocol = Browser.location.protocol;
			if (!url.startsWith("http")) url = '$protocol//$url';
			url = '/proxy?url=$url';
		}

		switch ext {
			case "ass":
				parseAss(video, url);
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
			if (isProxyError(text)) return;
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
			final textBase64 = "data:text/plain;base64,";
			final url = textBase64 + Base64.encode(Bytes.ofString(data));
			onParsed(video, "SRT subtitles", url);
		});
	}

	static function parseAss(video:VideoElement, url:String):Void {
		window.fetch(url).then(response -> {
			return response.text();
		}).then(text -> {
			if (isProxyError(text)) return;
			final subs:Array<{
				counter:Int,
				start:String,
				end:String,
				text:String,
			}> = [];
			final lines = text.replace("\r\n", "\n").split("\n");
			final matchFormat = ~/^Format:/;
			final matchDialogue = ~/^Dialogue:/;
			final blockTags = ~/\{\\[^}]*\}/g;
			final spaceTags = ~/\\(n|h)/g;
			final newLineTag = ~/\\N/g;
			final manyNewLineTags = ~/\\N(\\N)+/g;
			final drawingMode = ~/\\p[124]/;
			var eventStart = false;
			var formatFound = false;
			final ids:Map<String, Int> = [];
			var subsCounter = 1;
			for (rawLine in lines) {
				final line = rawLine.trim();
				if (!eventStart) {
					eventStart = line.startsWith("[Events]");
					continue;
				}

				if (!formatFound) {
					formatFound = matchFormat.match(line);
					if (!formatFound) continue;
					final list = matchFormat.replace(line, "").split(",");
					for (i in 0...list.length) {
						ids[list[i].trim()] = i;
					}
					ids["_length"] = list.length;
				}

				if (!matchDialogue.match(line)) continue;
				var list = matchDialogue.replace(line, "").split(",");
				while (list.length > ids["_length"]) {
					final el = list.pop();
					list[list.length - 1] += el;
				}
				list = list.map((e) -> e.trim());
				var text = list[ids["Text"]];
				if (drawingMode.match(text)) text = "";
				text = blockTags.replace(text, "");
				text = spaceTags.replace(text, " ");
				final nTag = "\\N";
				text = manyNewLineTags.replace(text, nTag);
				if (text.startsWith(nTag)) text = text.substr(nTag.length);
				if (text.endsWith(nTag)) text = text.substr(0, text.length - 2);
				text = newLineTag.replace(text, "\n");
				subs.push({
					counter: subsCounter,
					start: convertAssTime(list[ids["Start"]]),
					end: convertAssTime(list[ids["End"]]),
					text: text,
				});
				subsCounter++;
			}

			var data = "WEBVTT\n\n";
			for (sub in subs) {
				data += '${sub.counter}\n';
				data += '${sub.start} --> ${sub.end}\n';
				data += '${sub.text}\n\n';
			}
			final textBase64 = "data:text/plain;base64,";
			final url = textBase64 + Base64.encode(Bytes.ofString(data));
			onParsed(video, "ASS subtitles", url);
		});
	}

	static final assTimeStamp = ~/([0-9]+):([0-9][0-9]):([0-9][0-9]).([0-9][0-9])/;

	static function convertAssTime(time:String):String {
		if (!assTimeStamp.match(time)) {
			return toVttTime({
				h: 0,
				m: 0,
				s: 0,
				ms: 0,
			});
		}
		final h:Int = Std.parseInt(assTimeStamp.matched(1));
		final m:Int = Std.parseInt(assTimeStamp.matched(2));
		final s:Int = Std.parseInt(assTimeStamp.matched(3));
		final ms:Int = Std.parseInt(assTimeStamp.matched(4)) * 10;
		return toVttTime({
			h: h,
			m: m,
			s: s,
			ms: ms,
		});
	}

	static function parseVtt(video:VideoElement, url:String):Void {
		window.fetch(url).then(response -> response.text()).then(text -> {
			if (isProxyError(text)) return;
			final textBase64 = "data:text/plain;base64,";
			final url = textBase64 + Base64.encode(Bytes.ofString(text));
			onParsed(video, "VTT subtitles", url);
		});
	}

	static function isProxyError(text:String):Bool {
		if (text.startsWith("Proxy error:")) {
			Main.serverMessage(4, 'Failed to add subs: proxy error');
			trace('Failed to add subs: $text');
			return true;
		}
		return false;
	}

	static function onParsed(video:VideoElement, name:String, dataUrl:String) {
		final trackEl = document.createTrackElement();
		trackEl.kind = "captions";
		trackEl.label = name;
		trackEl.srclang = "en";
		trackEl.src = dataUrl;
		// trackEl.default_ = true;
		video.appendChild(trackEl);
		final track = trackEl.track;
		track.mode = SHOWING;
	}

	static inline function encodeURI(data:String):String {
		return js.Syntax.code("encodeURI({0})", data);
	}

	static inline function toVttTime(time:Duration):String {
		final h = '${time.h}'.lpad("0", 2);
		final m = '${time.m}'.lpad("0", 2);
		final s = '${time.s}'.lpad("0", 2);
		final ms = '${time.ms}'.lpad("0", 3).substr(0, 3);
		return '$h:$m:$s.$ms';
	}

	static inline function secondsToDuration(seconds:Float):Duration {
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
}
