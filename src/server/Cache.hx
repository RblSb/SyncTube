package server;

import haxe.io.Path;
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
	var storageLimit = 3 * 1024 * 1024 * 1024;
	final freeSpaceBlock = 10 * 1024 * 1024; // 10MB

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
		if (cachedFiles.contains(outName) && isFileExists(outName)) {
			callback(outName);
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
		final promise:Promise<YouTubeVideoInfo> = ytdl.getInfo(url);
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
			final videoFormat = getBestYoutubeVideoFormat(info.formats) ?? {
				log(client, "Error: video format not found");
				trace(info.formats.filter(item -> item.hasVideo));
				return;
			}

			final dlVideo:Readable<Dynamic> = ytdl(url, {
				format: videoFormat,
			});
			dlVideo.pipe(Fs.createWriteStream('$cacheDir/input-video'));
			dlVideo.on("error", err -> log(client, "Error during video download: " + err));

			final dlAudio:Readable<Dynamic> = ytdl(url, {
				format: audioFormat,
			});
			dlAudio.pipe(Fs.createWriteStream('$cacheDir/input-audio'));
			dlAudio.on("error", err -> log(client, "Error during audio download: " + err));

			var count = 0;
			function onComplete(type:String):Void {
				count++;
				trace('$type track downloaded ($count/2)');
				if (count < 2) return;
				var size = FileSystem.stat('$cacheDir/input-video').size;
				size += FileSystem.stat('$cacheDir/input-audio').size;
				// clean some space for full mp4
				removeOlderCache(size + freeSpaceBlock);

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
					FileSystem.deleteFile(inVideo);
					FileSystem.deleteFile(inAudio);

					add(outName);

					callback(outName);
				});
			}
			dlVideo.on("finish", () -> onComplete("Video"));
			dlAudio.on("finish", () -> onComplete("Audio"));
			var isAudioStart = true;
			dlAudio.on("progress", (chunkLength:Int, downloaded:Int, contentLength:Int) -> {
				if (isAudioStart) {
					isAudioStart = false;
					removeOlderCache(contentLength);
				}
			});
			var isVideoStart = true;
			dlVideo.on("progress", (chunkLength:Int, downloaded:Int, contentLength:Int) -> {
				if (isVideoStart) {
					isVideoStart = false;
					removeOlderCache(contentLength);
				}
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
			log(client, "" + err);
		});
	}

	public function setStorageLimit(bytes:Int) {
		storageLimit = cast bytes;
		storageLimit = storageLimit.limitMin(0);
		final statfs = (Fs : Dynamic).statfs ?? return;
		statfs("/", (err, stats) -> {
			if (err != null) {
				trace(err);
				return;
			}
			final availSpace = (stats.bsize * stats.bavail - freeSpaceBlock).limitMin(0);
			removeOlderCache();
			final freeSpace = getFreeSpace();
			if (availSpace < freeSpace) {
				// shrink limit lower than disk space
				storageLimit += availSpace - freeSpace;
				storageLimit = storageLimit.limitMin(0);
				removeOlderCache();
			}
		});
	}

	public function add(name:String) {
		if (!cachedFiles.contains(name)) {
			cachedFiles.unshift(name);
		}
	}

	public function removeOlderCache(addFileSize = 0):Void {
		var space = getUsedSpace(addFileSize);
		while (space > storageLimit) {
			final name = cachedFiles.pop() ?? break;
			final path = getFilePath(name);
			if (FileSystem.exists(path)) FileSystem.deleteFile(path);
			space = getUsedSpace(addFileSize);
		}
	}

	public function getFreeFileName(baseName = "video"):String {
		var i = 1;
		while (true) {
			final n = i == 1 ? "" : '$i';
			final name = '$baseName$n.mp4';
			if (!isFileExists(name)) return name;
			i++;
		}
	}

	public function getFilePath(name:String):String {
		return '$cacheDir/$name';
	}

	public function getFileUrl(name:String):String {
		final folder = Path.withoutDirectory(cacheDir);
		return '/$folder/$name';
	}

	public function isFileExists(name:String):Bool {
		return FileSystem.exists(getFilePath(name));
	}

	public function getFreeSpace():Int {
		return storageLimit - getUsedSpace();
	}

	public function getUsedSpace(addFileSize = 0):Int {
		var total = addFileSize.limitMin(0);
		for (name in cachedFiles.reversed()) {
			final path = getFilePath(name);
			if (!FileSystem.exists(path)) {
				cachedFiles.remove(name);
				continue;
			}
			total += FileSystem.stat(path).size;
		}
		return total;
	}

	function getBestYoutubeVideoFormat(formats:Array<YoutubeVideoFormat>):Null<YoutubeVideoFormat> {
		final qPriority = [1080, 720, 480, 360, 240, 144];
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
