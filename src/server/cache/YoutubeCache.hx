package server.cache;

import haxe.io.Path;
import js.node.child_process.ChildProcess as ChildProcessObject;
import sys.FileSystem;
import utils.YoutubeUtils;
import ytdlp_nodejs.VideoFormat;
import ytdlp_nodejs.VideoInfo;

class YoutubeCache {
	final main:Main;
	final cache:Cache;
	final ytdlp:YtdlpCache;

	public function new(main:Main, cache:Cache, ytdlp:YtdlpCache):Void {
		this.main = main;
		this.cache = cache;
		this.ytdlp = ytdlp;
	}

	public function cacheYoutubeVideo(client:Client, url:String, cb:CacheCallbacks) {
		if (!cache.isYtReady) {
			trace("Do `npm i https://github.com/RblSb/ytdlp-nodejs` to use cache feature (you also need to install `ffmpeg` to build mp4 from downloaded audio/video tracks).");
			return;
		}
		final clientName = client.name;
		final videoId = YoutubeUtils.extractVideoId(url);
		if (videoId == "") {
			log(clientName, 'Error: youtube video id not found in url: $url');
			return;
		}
		// to prevent playlist in url handlings
		url = 'https://youtu.be/$videoId';
		final outName = videoId + ".mp4";
		if (cache.exists(outName)) {
			cb.onResolved(cache.getFileUrl(outName));
			cb.onComplete();
			return;
		}
		final inVideoName = '__tmp-video-$videoId';
		inline function removeInputFiles():Void {
			ytdlp.cleanInputFiles(inVideoName);
		}
		inline function checkEnoughSpace(contentLength:Int):Bool {
			final hasSpace = cache.removeOlderCache(contentLength + cache.freeSpaceBlock);
			if (!hasSpace) {
				removeInputFiles();
				cb.onError();
				log(clientName, cache.notEnoughSpaceErrorText);
			}
			return hasSpace;
		}

		if (cache.isFileExists(inVideoName)) {
			log(clientName, 'Caching $outName already in progress');
			return;
		}
		trace('Caching $url to $outName...');
		cb.onResolved(cache.getFileUrl(outName));

		var useCookies = false;
		var lastSentRatio = 0.0;
		var canceled = false;
		var process:Null<ChildProcessObject> = null;
		if (cb.registerCancel != null) cb.registerCancel(() -> {
			canceled = true;
			process?.kill();
			removeInputFiles();
		});

		function onGetInfo(info:VideoInfo):Void {
			if (canceled) return;
			if (cb.onMetadata != null) cb.onMetadata(info.title, info.duration);
			trace('Get info with ${info.formats.length} formats');
			var aformats = info.formats.filter(f -> f.acodec != "none"
				&& f.vcodec == "none" && f.format_note?.contains("original"));
			if (aformats.length == 0) {
				aformats = info.formats.filter(f -> f.acodec != "none" && f.vcodec == "none");
			}
			if (aformats.length == 0) {
				aformats = info.formats.filter(f -> f.acodec != "none");
			}
			aformats.sort((a, b) -> (a?.filesize ?? 0) < (b?.filesize ?? 0) ? 1 : -1);
			final audioFormat:VideoFormat = aformats[0] ?? {
				log(clientName, "Error: format with audio not found");
				for (format in aformats) trace(format);
				cb.onError();
				return;
			}
			final vformats = info.formats.filter(f -> {
				if (f.vcodec == "none") return false;
				return f.width != null && f.height != null;
			});
			vformats.sort((a, b) -> (a?.filesize ?? 0) < (b?.filesize ?? 0) ? 1 : -1);
			var videoFormat = getBestYoutubeVideoFormat(vformats) ?? {
				log(clientName, "Error: video format not found");
				for (format in vformats) trace(format);
				cb.onError();
				return;
			}
			inline function getTotalFormatsSize():Int {
				final videoSize:Int = cast(videoFormat.filesize ?? 0);
				final audioSize:Int = cast(audioFormat.filesize ?? 0);
				return videoSize + audioSize;
			}
			// check if we have space for formats and video build
			final ignoreQualities:Array<Int> = [];
			for (i in 0...3) {
				final hasSpace = cache.removeOlderCache(getTotalFormatsSize() * 2
					+ cache.freeSpaceBlock);
				if (hasSpace) break;
				// try fallback to worse video quality
				ignoreQualities.push(videoFormatResolution(videoFormat));
				videoFormat = getBestYoutubeVideoFormat(vformats, ignoreQualities) ?? break;
			}
			if (!checkEnoughSpace(getTotalFormatsSize() * 2)) return;

			final isMuxed = videoFormat.format_id == audioFormat.format_id;
			final formatIds = if (isMuxed) {
				videoFormat.format_id;
			} else {
				'${videoFormat.format_id}+${audioFormat.format_id}';
			}
			final totalSize = getTotalFormatsSize().limitMin(10);
			var videoSizeRatio = (videoFormat.filesize ?? 0).limitMin(8) / totalSize;
			var audioSizeRatio = (audioFormat.filesize ?? 0).limitMin(2) / totalSize;
			if (isMuxed) {
				videoSizeRatio = 1;
				audioSizeRatio = 0;
			}
			trace(formatIds, toMibString(totalSize), videoSizeRatio.toFixed(), audioSizeRatio.toFixed());

			var videoRatioCache = 0.0;
			var audioRatioCache = 0.0;
			process = ytdlp.download(url, {
				format: formatIds,
				output: '${cache.cacheDir}/$inVideoName',
				remuxVideo: "mp4",
				additionalOptions: ytdlp.ytExtraOptions(),
				cookies: useCookies ? ytdlp.getCookiesPathOrNull() : null,
				forceIpv4: true,
				socketTimeout: 2,
				extractorRetries: 0,
			}, {
				onProgress: p -> {
					final isFinished = p.status == "finished";
					if (isFinished) {
						final filename = Path.withoutDirectory(p.filename);
						trace('$filename format file downloaded');
					}
					var ratio = if (isFinished) {
						1;
					} else {
						(p.downloaded / p.total).clamp(0, 1);
					}

					final isVideo = p.filename.contains('f${videoFormat.format_id}');
					if (isVideo) videoRatioCache = ratio;
					else audioRatioCache = ratio;

					ratio = videoRatioCache * videoSizeRatio + audioRatioCache * audioSizeRatio;

					if (canceled) return;
					if (ratio - lastSentRatio < 0.01 && ratio < 1) return;
					lastSentRatio = ratio;
					cb.onProgress(ratio.toFixed(4));
				},
				onComplete: () -> {
					if (canceled) {
						removeInputFiles();
						return;
					}
					final name = cache.findFile(n -> n.startsWith(inVideoName)) ?? {
						final err = 'Error: cannot find downloaded file with prefix $inVideoName';
						cache.logWithAdmins(client, err);
						cb.onError();
						return;
					};
					FileSystem.rename('${cache.cacheDir}/$name', '${cache.cacheDir}/$outName');
					removeInputFiles();
					cache.add(outName);
					cb.onComplete();
				},
				onError: err -> {
					if (canceled) return;
					final err = "Error during video download: " + err;
					cache.logWithAdmins(client, err);
					removeInputFiles();
					cb.onError();
				}
			});
		}

		ytdlp.getInfoAsync(url, useCookies).then(onGetInfo).catchError(err -> {
			trace(err);
			useCookies = true;
			ytdlp.getInfoAsync(url, useCookies).then(onGetInfo).catchError(err -> {
				removeInputFiles();
				cb.onError();
				log(clientName, "" + err);
			});
		});
	}

	function getBestYoutubeVideoFormat(formats:Array<VideoFormat>, ?ignoreQualities:Array<Int>):Null<VideoFormat> {
		final qPriority = [1080, 720, 480, 360, 240, 144];
		if (ignoreQualities != null) {
			for (q in ignoreQualities) qPriority.remove(q);
		}
		final format60 = findVideoFormat(formats, qPriority, true);
		return format60 ?? findVideoFormat(formats, qPriority, false);
	}

	function findVideoFormat(formats:Array<VideoFormat>, qPriority:Array<Int>, is60fps:Bool):Null<VideoFormat> {
		for (q in qPriority) {
			final quality = '${q}p' + (is60fps ? "60" : "");
			for (format in formats) {
				final min = videoFormatResolution(format);
				if (min > q) continue;
				final format_note = formatVideoQuality(format);
				if (format_note == quality) return format;
			}
		}
		return null;
	}

	function videoFormatResolution(format:VideoFormat):Int {
		final min = Math.min(format.width, format.height);
		return Std.int(min);
	}

	function formatVideoQuality(format:VideoFormat):Null<String> {
		final resolution = videoFormatResolution(format);
		// when there is 720p and 720p60 formats
		return format.format_note ?? '${resolution}p';
	}

	inline function toMibString(bytes:Int):String {
		return '${(bytes / 1024 / 1024).toFixed()} MiB';
	}

	function log(clientName:String, msg:String):Void {
		cache.logByName(clientName, msg);
	}
}
