package server.cache;

import haxe.Json;
import js.lib.Promise;
import js.node.Buffer;
import js.node.ChildProcess;
import js.node.Fs.Fs;
import js.node.stream.Readable;
import sys.FileSystem;
import sys.io.File;
import utils.YoutubeUtils;

class YoutubeCache {
	final main:Main;
	final cache:Cache;

	public function new(main:Main, cache:Cache):Void {
		this.main = main;
		this.cache = cache;
	}

	public function checkYtDeps():Bool {
		final ytdl = try {
			untyped require("@distube/ytdl-core");
		} catch (e) {
			return false;
		}
		try {
			ChildProcess.execSync("ffmpeg -version", {stdio: "ignore", timeout: 3000});
			return true;
		} catch (e) {
			return false;
		}
	}

	public function cleanYtInputFiles():Void {
		final names = FileSystem.readDirectory(cache.cacheDir);
		for (name in names) {
			if (!name.startsWith("__tmp")) continue;
			cache.remove(name);
		}
	}

	public function cacheYoutubeVideo(client:Client, url:String, callback:(name:String) -> Void) {
		if (!cache.isYtReady) {
			trace("Do `npm i @distube/ytdl-core@latest` to use cache feature (you also need to install `ffmpeg` to build mp4 from downloaded audio/video tracks).");
			return;
		}
		final videoId = YoutubeUtils.extractVideoId(url);
		if (videoId == "") {
			log(client, 'Error: youtube video id not found in url: $url');
			return;
		}
		final outName = videoId + ".mp4";
		if (cache.exists(outName)) {
			callback(outName);
			return;
		}
		final inVideoName = '__tmp-video-$videoId';
		final inAudioName = '__tmp-audio-$videoId';
		inline function removeInputFiles():Void {
			cache.remove(inVideoName);
			cache.remove(inAudioName);
		}
		inline function checkEnoughSpace(contentLength:Int):Bool {
			final hasSpace = cache.removeOlderCache(contentLength + cache.freeSpaceBlock);
			if (!hasSpace) {
				removeInputFiles();
				cancelProgress(client);
				log(client, cache.notEnoughSpaceErrorText);
			}
			return hasSpace;
		}

		if (cache.isFileExists(inVideoName)) {
			log(client, 'Caching $outName already in progress');
			return;
		}
		final ytdl:Dynamic = untyped require("@distube/ytdl-core");
		trace('Caching $url to $outName...');
		main.send(client, {
			type: Progress,
			progress: {
				type: Caching,
				ratio: 0,
				data: outName
			}
		});
		var agent:Any = null;
		final cookiesPath = '${main.userDir}/cookies.json';
		if (FileSystem.exists(cookiesPath)) {
			agent = ytdl.createAgent(Json.parse(File.getContent(cookiesPath)));
		}
		final promise:Promise<YouTubeVideoInfo> = ytdl.getInfo(url, {
			agent: agent,
		});
		promise.then(info -> {
			trace('Get info with ${info.formats.length} formats');
			final audioFormat:YoutubeVideoFormat = try {
				ytdl.chooseFormat(info.formats.filter(item -> {
					return item.audioCodec?.startsWith("mp4a");
				}), {quality: "highestaudio"});
			} catch (e) {
				log(client, "Error: audio format not found");
				trace(e);
				trace(info.formats.filter(item -> item.hasAudio));
				return;
			}
			var videoFormat = getBestYoutubeVideoFormat(info.formats) ?? {
				log(client, "Error: video format not found");
				trace(info.formats.filter(item -> item.hasVideo));
				return;
			}
			inline function getTotalFormatsSize():Int {
				final videoSize = Std.parseInt(videoFormat.contentLength) ?? 0;
				final audioSize = Std.parseInt(audioFormat.contentLength) ?? 0;
				return videoSize + audioSize;
			}
			// check if we have space for formats and video build
			final hasSpace = cache.removeOlderCache(getTotalFormatsSize() * 2
				+ cache.freeSpaceBlock);
			if (!hasSpace) {
				// try fallback to worse video quality
				videoFormat = getBestYoutubeVideoFormat(info.formats, videoFormat.qualityLabel);
				if (!checkEnoughSpace(getTotalFormatsSize() * 2)) return;
			}

			final dlVideo:Readable<Dynamic> = ytdl(url, {
				format: videoFormat,
				agent: agent,
			});
			dlVideo.pipe(Fs.createWriteStream('${cache.cacheDir}/$inVideoName'));
			dlVideo.on("error", err -> {
				log(client, "Error during video download: " + err);
				removeInputFiles();
				cancelProgress(client);
			});

			final dlAudio:Readable<Dynamic> = ytdl(url, {
				format: audioFormat,
				agent: agent,
			});
			dlAudio.pipe(Fs.createWriteStream('${cache.cacheDir}/$inAudioName'));
			dlAudio.on("error", err -> {
				log(client, "Error during audio download: " + err);
				removeInputFiles();
				cancelProgress(client);
			});

			var count = 0;
			function onComplete(type:String):Void {
				count++;
				trace('$type track downloaded ($count/2)');
				if (count < 2) return;
				if (!cache.isFileExists(inVideoName) || !cache.isFileExists(inAudioName)) {
					log(client, "Input files not found for making final video");
					removeInputFiles();
					cancelProgress(client);
					return;
				}
				var size = FileSystem.stat('${cache.cacheDir}/$inVideoName').size;
				size += FileSystem.stat('${cache.cacheDir}/$inAudioName').size;
				// clean some space for full mp4
				if (!checkEnoughSpace(size)) return;

				final args = '-y -i ./$inVideoName -i ./$inAudioName -c copy -map 0:v -map 1:a ./$outName'.split(" ");
				final process = ChildProcess.spawn("ffmpeg", args, {
					cwd: cache.cacheDir,
					// stdio: "ignore"
				});
				final outputData:Array<Buffer> = [];
				process.stderr.on("data", (data) -> outputData.push(data));
				process.on("close", (code:Int) -> {
					removeInputFiles();
					if (code != 0) {
						cancelProgress(client);
						final errCodeMsg = 'Error: ffmpeg closed with code $code';
						final admins = main.clients.filter(client -> client.isAdmin);
						for (client in admins) {
							log(client, Buffer.concat(outputData).toString());
							log(client, errCodeMsg);
						}
						if (!admins.contains(client)) log(client, errCodeMsg);
						return;
					}
					cache.add(outName);

					callback(outName);
				});
			}
			dlVideo.on("finish", () -> onComplete("Video"));
			dlAudio.on("finish", () -> onComplete("Audio"));
			dlVideo.on("progress", (chunkLength:Int, downloaded:Int, contentLength:Int) -> {
				final ratio = (downloaded / contentLength).clamp(0, 1);
				main.send(client, {
					type: Progress,
					progress: {
						type: Downloading,
						ratio: ratio
					}
				});
			});
		}).catchError(err -> {
			removeInputFiles();
			cancelProgress(client);
			log(client, "" + err);
		});
	}

	function getBestYoutubeVideoFormat(formats:Array<YoutubeVideoFormat>, ?ignoreQuality:String):Null<YoutubeVideoFormat> {
		final qPriority = [1080, 720, 480, 360, 240, 144];
		for (q in qPriority) {
			final quality = '${q}p';
			if (quality == ignoreQuality) continue;
			for (format in formats) {
				if (format.videoCodec == null) continue;
				if (format.qualityLabel == quality) return format;
			}
		}
		return null;
	}

	function log(client:Client, msg:String):Void {
		cache.log(client, msg);
	}

	function cancelProgress(client:Client):Void {
		main.send(client, {
			type: Progress,
			progress: {
				type: Canceled,
				ratio: 0
			}
		});
	}
}
