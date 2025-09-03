package server.cache;

import haxe.Json;
import js.lib.Promise;
import js.node.ChildProcess;
import sys.FileSystem;
import utils.YoutubeUtils;
import ytdlp_nodejs.VideoFormat;
import ytdlp_nodejs.VideoInfo;
import ytdlp_nodejs.YtDlp;

class YoutubeCache {
	final main:Main;
	final cache:Cache;
	var ytDlp:Null<YtDlp>;

	public function new(main:Main, cache:Cache):Void {
		this.main = main;
		this.cache = cache;
	}

	public function checkYtDeps():Bool {
		try {
			ChildProcess.execSync("ffmpeg -version", {stdio: "ignore", timeout: 5000});
			ytDlp = js.Syntax.code("new (require('ytdlp-nodejs')).YtDlp()");
			return true;
		} catch (e) {
			return false;
		}
	}

	public function checkUpdate():Void {
		ytDlp.execAsync("-U", {
			onData: d -> {
				trace(d);
			}
		}).catchError(e -> {
			trace(e);
		});
	}

	public function cleanYtInputFiles(prefix = "__tmp"):Void {
		final names = FileSystem.readDirectory(cache.cacheDir);
		for (name in names) {
			if (!name.startsWith(prefix)) continue;
			cache.remove(name);
		}
	}

	public function cacheYoutubeVideo(client:Client, url:String, callback:(name:String) -> Void) {
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
		final outName = videoId + ".mp4";
		if (cache.exists(outName)) {
			callback(outName);
			return;
		}
		final inVideoName = '__tmp-video-$videoId';
		inline function removeInputFiles():Void {
			cleanYtInputFiles(inVideoName);
		}
		inline function checkEnoughSpace(contentLength:Int):Bool {
			final hasSpace = cache.removeOlderCache(contentLength + cache.freeSpaceBlock);
			if (!hasSpace) {
				removeInputFiles();
				cancelProgress(clientName);
				log(clientName, cache.notEnoughSpaceErrorText);
			}
			return hasSpace;
		}

		if (cache.isFileExists(inVideoName)) {
			log(clientName, 'Caching $outName already in progress');
			return;
		}
		trace('Caching $url to $outName...');
		main.sendByName(clientName, {
			type: Progress,
			progress: {
				type: Caching,
				ratio: 0,
				data: outName
			}
		});

		var useCookies = false;

		function onGetInfo(info:VideoInfo):Void {
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

			final formatIds = if (videoFormat.format_id == audioFormat.format_id) {
				videoFormat.format_id;
			} else {
				'${videoFormat.format_id}+${audioFormat.format_id}';
			}
			var totalSize = getTotalFormatsSize().limitMin(10);
			var videoSizeRatio = (videoFormat.filesize ?? 0).limitMin(8) / totalSize;
			var audioSizeRatio = (audioFormat.filesize ?? 0).limitMin(2) / totalSize;
			var isVideoFormatDownloading = true;
			final dlVideo:Promise<String> = ytDlp.downloadAsync(url, {
				format: formatIds,
				output: '${cache.cacheDir}/$inVideoName',
				remuxVideo: "mp4",
				cookies: useCookies ? getCookiesPathOrNull() : null,
				forceIpv4: true,
				socketTimeout: 2,
				extractorRetries: 0,
				onProgress: p -> {
					final isFinished = p.status == "finished";
					var ratio = if (isFinished) {
						1;
					} else {
						(p.downloaded / p.total).clamp(0, 1);
					}
					if (isVideoFormatDownloading) {
						ratio = ratio * videoSizeRatio;
					} else {
						ratio = videoSizeRatio + ratio * audioSizeRatio;
					}
					if (isFinished) isVideoFormatDownloading = false;
					main.sendByName(clientName, {
						type: Progress,
						progress: {
							type: Downloading,
							ratio: ratio.toFixed(4)
						}
					});
				}
			}).catchError(err -> {
				final err = "Error during video download: " + err;
				cache.logWithAdmins(client, err);
				removeInputFiles();
				cancelProgress(clientName);
			});

			dlVideo.then((v) -> {
				final name = cache.findFile(n -> n.startsWith(inVideoName) && n.endsWith(".mp4")) ?? {
					final err = 'Error: cannot find downloaded file with prefix $inVideoName';
					cache.logWithAdmins(client, err);
					return;
				};
				FileSystem.rename('${cache.cacheDir}/$name', '${cache.cacheDir}/$outName');
				removeInputFiles();
				cache.add(outName);
				callback(outName);
			});
		}

		getInfoAsync(url, useCookies).then(onGetInfo).catchError(err -> {
			trace(err);
			useCookies = true;
			getInfoAsync(url, useCookies).then(onGetInfo).catchError(err -> {
				removeInputFiles();
				cancelProgress(clientName);
				log(clientName, "" + err);
			});
		});
	}

	function getInfoAsync(url:String, useCookies = false):Promise<VideoInfo> {
		return cast ytDlp.getInfoAsync(url, {
			cookies: useCookies ? getCookiesPathOrNull() : null,
		});
	}

	function getCookiesPathOrNull():Null<String> {
		final cookiesPath = '${main.userDir}/cookies.txt';
		return FileSystem.exists(cookiesPath) ? cookiesPath : null;
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

	function log(clientName:String, msg:String):Void {
		cache.logByName(clientName, msg);
	}

	function cancelProgress(clientName:String):Void {
		main.sendByName(clientName, {
			type: Progress,
			progress: {
				type: Canceled,
				ratio: 0
			}
		});
	}
}
