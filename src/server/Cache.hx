package server;

import js.lib.Promise;
import js.node.ChildProcess;
import js.node.Fs.Fs;
import js.node.stream.Readable;
import sys.FileSystem;
import utils.YoutubeUtils;

class Cache {
	final main:Main;
	final cacheDir:String;

	public final cachedFiles:Array<String> = [];

	public final isYtReady = false;

	/** In bytes **/
	public var storageLimit = 3 * 1024 * 1024 * 1024;

	public function new(main:Main, cacheDir:String) {
		this.main = main;
		this.cacheDir = cacheDir;
		Utils.ensureDir(cacheDir);
		isYtReady = checkYtDeps();
	}

	function checkYtDeps():Bool {
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

	function log(client:Client, msg:String):Void {
		main.serverMessage(client, msg);
		trace(msg);
	}

	public function cacheYoutubeVideo(client:Client, url:String, callback:(name:String) -> Void) {
		if (!isYtReady) {
			trace("Do `npm i @distube/ytdl-core@latest` to use cache feature (you also need to install `ffmpeg` to build mp4 from downloaded audio/video tracks).");
			return;
		}
		final videoId = YoutubeUtils.extractVideoId(url);
		if (videoId == "") {
			log(client, 'Error: youtube video id not found in url: $url');
			return;
		}
		final outName = videoId + ".mp4";
		if (cachedFiles.contains(outName) && FileSystem.exists('$cacheDir/$outName')) {
			callback(outName);
			return;
		}
		final ytdl:Dynamic = untyped require("@distube/ytdl-core");
		log(client, 'Caching $url to $outName...');
		final opts = {playerClients: ["IOS", "WEB_CREATOR"]};
		final promise:Promise<YouTubeVideoInfo> = ytdl.getInfo(url, opts);
		promise.then(info -> {
			// trace(info.formats.filter(item -> item.audioCodec != null));
			trace('Get info with ${info.formats.length} formats');
			final audioFormat:YoutubeVideoFormat = try {
				ytdl.chooseFormat(info.formats.filter(item -> {
					return item.audioCodec?.startsWith("mp4a");
				}), {quality: "highestaudio"});
			} catch (e) {
				log(client, "Error: audio format not found");
				trace(e);
				trace(info.formats);
				return;
			}
			final videoFormat = getBestYoutubeVideoFormat(info.formats) ?? {
				log(client, "Error: video format not found");
				trace(info.formats);
				return;
			}
			trace("Picked audio and video formats");

			final dlVideo:Readable<Dynamic> = ytdl(url, {
				format: videoFormat,
				playerClients: opts.playerClients
			});
			dlVideo.pipe(Fs.createWriteStream('$cacheDir/input-video'));
			dlVideo.on("error", err -> log(client, "Error during video download: " + err));

			final dlAudio:Readable<Dynamic> = ytdl(url, {
				format: audioFormat,
				playerClients: opts.playerClients
			});
			dlAudio.pipe(Fs.createWriteStream('$cacheDir/input-audio'));
			dlAudio.on("error", err -> log(client, "Error during audio download: " + err));

			var count = 0;
			function onComplete(type:String):Void {
				count++;
				log(client, '$type track downloaded ($count/2)');
				if (count < 2) return;
				final args = '-y -i input-video -i input-audio -c copy -map 0:v -map 1:a ./$outName'.split(" ");
				final process = ChildProcess.spawn("ffmpeg", args, {
					cwd: cacheDir,
					stdio: "ignore"
				});
				// process.stderr.on('data', (data) -> {
				// 	trace('FFmpeg stderr: ${data}');
				// });
				process.on("close", (code:Int) -> {
					if (code != 0) {
						log(client, 'Error: ffmpeg closed with code $code');
						return;
					}
					final inVideo = '$cacheDir/input-video';
					final inAudio = '$cacheDir/input-audio';
					if (FileSystem.exists(inVideo)) FileSystem.deleteFile(inVideo);
					if (FileSystem.exists(inAudio)) FileSystem.deleteFile(inAudio);

					if (!cachedFiles.contains(outName)) {
						cachedFiles.unshift(outName);
					}
					removeOlderCache();

					callback(outName);
				});
			}
			dlVideo.on("finish", () -> onComplete("Video"));
			dlAudio.on("finish", () -> onComplete("Audio"));
			// dlVideo.on('progress', (c, d, t) -> {
			// 	final progress = Std.int((d / t * 100) * 10) / 10;
			// 	trace(progress);
			// });
		}).catchError(err -> {
			log(client, "" + err);
		});
	}

	function removeOlderCache():Void {
		while (getUsedSpace() > storageLimit) {
			final name = cachedFiles.pop();
			final path = '$cacheDir/$name';
			if (FileSystem.exists(path)) FileSystem.deleteFile(path);
		}
	}

	function getUsedSpace():Int {
		var total = 0;
		for (name in cachedFiles.reversed()) {
			final path = '$cacheDir/$name';
			if (!FileSystem.exists(path)) {
				cachedFiles.remove(name);
				continue;
			}
			total += FileSystem.stat(path).size;
		}
		return total;
	}

	function getBestYoutubeVideoFormat(formats:Array<YoutubeVideoFormat>):Null<YoutubeVideoFormat> {
		final qPriority = [1080, 720, 480, 360, 240];
		for (q in qPriority) {
			final quality = '${q}p';
			for (format in formats) {
				if (format.videoCodec == null) continue;
				if (format.qualityLabel == quality) return format;
			}
		}
		return null;
	}
}
