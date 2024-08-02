package server;

import haxe.Json;
import js.lib.Function;
import js.lib.Object;
import js.lib.Promise;
import js.node.Https.Https;
import js.node.Https.HttpsRequestOptions;
import js.node.url.URLSearchParams;
import utils.YoutubeUtils;

class YoutubeFallback {
	static function httpsGet(
		url:String,
		?options:HttpsRequestOptions,
		?callback:(status:Int, data:String) -> Void
	):Void {
		final request = Https.get(url, options, res -> {
			var data = "";
			res.on("data", chunk -> data += chunk.toString());
			res.on("end", () -> callback(res.statusCode, data));
		});
		request.on("error", err -> {
			trace(url);
			trace("request error: ", err);
		});
	}

	public static function resolvePlayerResponse(watchHtml:String):String {
		if (watchHtml == null) return "";
		final resReg = ~/ytInitialPlayerResponse = (.*)}}};/;
		var matches = resReg.match(watchHtml);
		return matches ? resReg.matched(1) + "}}}" : "";
	}

	public static function resoleM3U8Link(watchHtml:String):Null<String> {
		if (watchHtml == null) return null;
		final hlsReg = ~/hlsManifestUrl":"(.*\/file\/index\.m3u8)/;
		return hlsReg.match(watchHtml) ? hlsReg.matched(1) : null;
	}

	public static function buildDecoder(watchHtml:String, callback:(decoder:(cipher:String) -> String) -> Void):Void {
		if (watchHtml == null) return callback(null);

		final jsFileUrlReg = ~/\/s\/player\/[A-Za-z0-9]+\/[A-Za-z0-9_.]+\/[A-Za-z0-9_]+\/base\.js/;
		if (!jsFileUrlReg.match(watchHtml)) return callback(null);

		final url = "https://www.youtube.com" + jsFileUrlReg.matched(0);
		httpsGet(url, {}, (status, jsFileContent) -> {
			final funcReg = ~/function.*\.split\(""\).*\.join\(""\)}/;
			if (!funcReg.match(jsFileContent)) return callback(null);

			final decodeFunction = funcReg.matched(0);
			final varNameReg = ~/\.split\(""\);([a-zA-Z0-9]+)\./i;
			if (!varNameReg.match(decodeFunction)) return callback(null);

			final varStartIndex = jsFileContent.indexOf("var " + varNameReg.matched(1) + "={");
			if (varStartIndex < 0) return callback(null);

			final varEndIndex = jsFileContent.indexOf("}};", varStartIndex);
			if (varEndIndex < 0) return callback(null);

			final varDeclares = jsFileContent.substring(varStartIndex, varEndIndex + 3);
			if (varDeclares.length == 0) return callback(null);

			callback(signatureCipher -> {
				final params = new URLSearchParams(signatureCipher);
				final obj = Object.fromEntries(params);
				final signature = obj.s;
				final signatureParam = obj.sp ?? "signature";
				final url = obj.url;
				final decodedSignature = new Function('
					"use strict";
					$varDeclares
					return ($decodeFunction)("$signature");
				').call(null);
				return '$url&$signatureParam=${untyped encodeURIComponent(decodedSignature)}';
			});
		});
	}

	public static function getInfo(url:String, callback:(info:Null<YouTubeVideoInfo>) -> Void):Void {
		final videoId = YoutubeUtils.extractVideoId(url);
		if (videoId.length == 0) {
			trace("youtube videoId is not found");
			return callback(null);
		}

		final url = 'https://www.youtube.com/watch?v=$videoId';
		httpsGet(url, {}, (status, data) -> {
			if (status != 200 || data.length == 0) {
				trace("Cannot get youtube video response");
				return callback(null);
			}

			final ytInitialPlayerResponse = resolvePlayerResponse(data);
			final parsedResponse = Json.parse(ytInitialPlayerResponse);
			final streamingData:YouTubeVideoInfo = parsedResponse.streamingData ?? cast {};
			streamingData.formats ??= [];
			streamingData.adaptiveFormats ??= [];
			var formats:Array<YoutubeVideoFormat> = streamingData.formats.concat(streamingData.adaptiveFormats);

			final promises:Array<Promise<Any>> = [];

			final isEncryptedVideo = formats.exists(it -> it.signatureCipher != null);
			if (isEncryptedVideo) {
				final promise = new Promise((resolve, reject) -> {
					buildDecoder(data, decoder -> {
						if (decoder != null) {
							formats = formats.map(item -> {
								if (item.url != null || item.signatureCipher == null) return item;

								item.url = decoder(item.signatureCipher);
								item.signatureCipher = null;
								return item;
							});
						}
						resolve(null);
					});
				});
				promises.push(promise);
			}

			Promise.all(promises).then(_ -> {
				final result:YouTubeVideoInfo = {
					videoDetails: parsedResponse.videoDetails ?? cast {},
					formats: formats.filter(format -> format.url != null)
				};
				if (result.videoDetails.isLiveContent) {
					final m3u8Link = resoleM3U8Link(data);
					try {
						result.liveData = {
							manifestUrl: m3u8Link,
							// data: m3u8Parser.getResult()
						};
					}
				}
				callback(result);
			});
		});
	}
}
