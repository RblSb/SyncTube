package server;

import haxe.Json;
import haxe.io.Path;
import js.lib.Promise;
import js.node.Buffer;
import js.node.ChildProcess;
import js.node.Fs.Fs;
import js.node.stream.Readable;
import sys.FileSystem;
import sys.io.File;
import utils.YoutubeUtils;

class Cache {
	public final notEnoughSpaceErrorText = "Error: Not enough free space on server or file size is out of cache storage limit.";

	public final isYtReady = false;

	/** In bytes **/
	public var storageLimit(default, null) = 3 * 1024 * 1024 * 1024;

	final main:Main;
	final cacheDir:String;
	final cachedFiles:Array<String> = [];
	final freeSpaceBlock = 10 * 1024 * 1024; // 10MB

	public function new(main:Main, cacheDir:String) {
		this.main = main;
		this.cacheDir = cacheDir;
		Utils.ensureDir(cacheDir);
		isYtReady = checkYtDeps();
		if (isYtReady) cleanYtInputFiles();
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

	function cleanYtInputFiles():Void {
		final names = FileSystem.readDirectory(cacheDir);
		for (name in names) {
			if (!name.startsWith("__tmp")) continue;
			remove(name);
		}
	}

	public function getCachedFiles():Array<String> {
		return cachedFiles;
	}

	public function setCachedFiles(names:Array<String>) {
		cachedFiles.resize(0);
		for (name in names) cachedFiles.push(name);

		final names = FileSystem.readDirectory(cacheDir);
		for (name in names) {
			if (name.startsWith(".")) continue;
			if (FileSystem.isDirectory('$cacheDir/$name')) continue;
			if (cachedFiles.contains(name)) continue;
			trace('Remove non-tracked cache $name');
			remove(name);
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
		final inVideoName = '__tmp-video-$videoId';
		final inAudioName = '__tmp-audio-$videoId';
		inline function removeInputFiles():Void {
			remove(inVideoName);
			remove(inAudioName);
		}
		inline function cancelProgress():Void {
			main.send(client, {
				type: Progress,
				progress: {
					type: Canceled,
					ratio: 1
				}
			});
		}
		if (isFileExists(inVideoName)) {
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
			final videoFormat = getBestYoutubeVideoFormat(info.formats) ?? {
				log(client, "Error: video format not found");
				trace(info.formats.filter(item -> item.hasVideo));
				return;
			}

			final dlVideo:Readable<Dynamic> = ytdl(url, {
				format: videoFormat,
				agent: agent,
			});
			dlVideo.pipe(Fs.createWriteStream('$cacheDir/$inVideoName'));
			dlVideo.on("error", err -> {
				log(client, "Error during video download: " + err);
				removeInputFiles();
				cancelProgress();
			});

			final dlAudio:Readable<Dynamic> = ytdl(url, {
				format: audioFormat,
				agent: agent,
			});
			dlAudio.pipe(Fs.createWriteStream('$cacheDir/$inAudioName'));
			dlAudio.on("error", err -> {
				log(client, "Error during audio download: " + err);
				removeInputFiles();
				cancelProgress();
			});

			var count = 0;
			function onComplete(type:String):Void {
				count++;
				trace('$type track downloaded ($count/2)');
				if (count < 2) return;
				if (!isFileExists(inVideoName) || !isFileExists(inAudioName)) {
					log(client, "Input files not found for making final video");
					removeInputFiles();
					cancelProgress();
					return;
				}
				var size = FileSystem.stat('$cacheDir/$inVideoName').size;
				size += FileSystem.stat('$cacheDir/$inAudioName').size;
				// clean some space for full mp4
				final hasSpace = removeOlderCache(size + freeSpaceBlock);
				if (!hasSpace) {
					removeInputFiles();
					cancelProgress();
					log(client, notEnoughSpaceErrorText);
					return;
				}

				final args = '-y -i ./$inVideoName -i ./$inAudioName -c copy -map 0:v -map 1:a ./$outName'.split(" ");
				final process = ChildProcess.spawn("ffmpeg", args, {
					cwd: cacheDir,
					// stdio: "ignore"
				});
				final outputData:Array<Buffer> = [];
				process.stderr.on("data", (data) -> outputData.push(data));
				process.on("close", (code:Int) -> {
					removeInputFiles();
					if (code != 0) {
						cancelProgress();
						final errCodeMsg = 'Error: ffmpeg closed with code $code';
						final admins = main.clients.filter(client -> client.isAdmin);
						for (client in admins) {
							log(client, Buffer.concat(outputData).toString());
							log(client, errCodeMsg);
						}
						if (!admins.contains(client)) log(client, errCodeMsg);
						return;
					}
					add(outName);

					callback(outName);
				});
			}
			dlVideo.on("finish", () -> onComplete("Video"));
			dlAudio.on("finish", () -> onComplete("Audio"));
			inline function checkEnoughSpace(contentLength:Int):Void {
				final hasSpace = removeOlderCache(contentLength + freeSpaceBlock);
				if (!hasSpace) {
					dlVideo.destroy();
					dlAudio.destroy();
					removeInputFiles();
					cancelProgress();
					main.serverMessage(client, notEnoughSpaceErrorText);
				}
			}
			var isAudioStart = true;
			dlAudio.on("progress", (chunkLength:Int, downloaded:Int, contentLength:Int) -> {
				if (isAudioStart) {
					isAudioStart = false;
					checkEnoughSpace(contentLength);
				}
			});
			var isVideoStart = true;
			dlVideo.on("progress", (chunkLength:Int, downloaded:Int, contentLength:Int) -> {
				if (isVideoStart) {
					isVideoStart = false;
					checkEnoughSpace(contentLength);
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
			removeInputFiles();
			cancelProgress();
			log(client, "" + err);
		});
	}

	public function setStorageLimit(bytes:Int) {
		storageLimit = cast bytes;
		storageLimit = storageLimit.limitMin(0);
		getFreeDiskSpace(availSpace -> {
			final availSpace = (availSpace - freeSpaceBlock).limitMin(0);
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

	public function getFreeDiskSpace(callback:(availSpace:Int) -> Void):Void {
		final statfs = (Fs : Dynamic).statfs ?? {
			trace("Warning: no fs.statfs support in current nodejs version (needs v18+)");
			callback(storageLimit);
			return;
		}
		statfs("/", (err, stats) -> {
			if (err != null) {
				trace(err);
				callback(storageLimit);
				return;
			}
			callback(stats.bsize * stats.bavail);
		});
	}

	public function add(name:String) {
		if (!cachedFiles.contains(name)) {
			cachedFiles.unshift(name);
		}
	}

	public function remove(name:String):Void {
		cachedFiles.remove(name);
		removeFile(name);
	}

	/** Returns `true` if there is enough space to save `addFileSize` bytes. **/
	public function removeOlderCache(addFileSize = 0):Bool {
		var space = getUsedSpace(addFileSize);
		while (space > storageLimit) {
			final name = cachedFiles.pop() ?? break;
			removeFile(name);
			space = getUsedSpace(addFileSize);
		}
		return space < storageLimit;
	}

	function removeFile(name:String):Void {
		final path = getFilePath(name);
		if (FileSystem.exists(path)) FileSystem.deleteFile(path);
	}

	public function getFreeFileName(fullName = "video.mp4"):String {
		final baseName = Path.withoutDirectory(Path.withoutExtension(fullName));
		final ext = Path.extension(fullName);
		var i = 1;
		while (true) {
			final n = i == 1 ? "" : '$i';
			final name = '$baseName$n.$ext';
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
