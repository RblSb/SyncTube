package server.cache;

import haxe.io.Path;
import js.node.Fs.Fs;
import sys.FileSystem;

class Cache {
	public final notEnoughSpaceErrorText = "Error: Not enough free space on server or file size is out of cache storage limit.";

	public final isYtReady = false;

	/** In bytes **/
	public var storageLimit(default, null) = 3 * 1024 * 1024 * 1024;

	final main:Main;

	public final cacheDir:String;
	public final freeSpaceBlock = 10 * 1024 * 1024; // 10MB

	final cachedFiles:Array<String> = [];
	var youtubeCache:YoutubeCache;
	var rawCache:RawCache;

	public function new(main:Main, cacheDir:String) {
		this.main = main;
		this.cacheDir = cacheDir;
		Utils.ensureDir(cacheDir);
		youtubeCache = new YoutubeCache(main, this);
		rawCache = new RawCache(main, this);
		isYtReady = youtubeCache.checkYtDeps();
		if (isYtReady) youtubeCache.cleanYtInputFiles();
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

	public function log(client:Client, msg:String):Void {
		main.serverMessage(client, msg);
		trace(msg);
	}

	public function cacheYoutubeVideo(client:Client, url:String, callback:(name:String) -> Void) {
		youtubeCache.cacheYoutubeVideo(client, url, callback);
	}

	public function cacheRawVideo(client:Client, url:String, callback:(name:String) -> Void) {
		rawCache.cacheRawVideo(client, url, callback);
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

	public function exists(name:String):Bool {
		return cachedFiles.contains(name) && isFileExists(name);
	}

	/** Returns `true` if there is enough space to save `addFileSize` bytes. **/
	public function removeOlderCache(addFileSize = 0):Bool {
		var space = getUsedSpace(addFileSize);
		for (name in cachedFiles.reversed()) {
			if (space <= storageLimit) break;
			// do not remove cached items that are in playlist
			if (main.hasPlaylistUrl(getFileUrl(name))) continue;
			remove(name);
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
}
