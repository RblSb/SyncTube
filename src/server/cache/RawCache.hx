package server.cache;

import js.node.Buffer;
import js.node.ChildProcess;
import js.node.Fs.Fs;
import js.node.Http;
import js.node.Https;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;
import sys.FileSystem;
import sys.io.File;

typedef Segment = {
	i:Int,
	url:String,
	started:Bool,
	completed:Bool,
	name:String
}

class RawCache {
	final main:Main;
	final cache:Cache;

	public function new(main:Main, cache:Cache):Void {
		this.main = main;
		this.cache = cache;
	}

	public function cacheRawVideo(client:Client, url:String, cb:CacheCallbacks) {
		final isM3U8 = url.contains(".m3u8");
		final ext = isM3U8 ? "m3u8" : "mp4";

		final matchName = ~/^([^:?#\\\/\.]+)\.(.+)/;
		final decodedUrl = try url.urlDecode() catch (e) url;
		final lastPart = decodedUrl.substr(decodedUrl.lastIndexOf("/") + 1);
		var outName = matchName.match(lastPart) ? matchName.matched(1)
			+ '.$ext' : 'video.$ext';
		outName = cache.getFreeFileName(outName);

		if (cache.exists(outName)) {
			cb.onResolved(cache.getFileUrl(outName));
			cb.onComplete();
			return;
		}

		trace('Caching $url to $outName...');
		cb.onResolved(cache.getFileUrl(outName));

		if (isM3U8) {
			handleM3u8(client, url, outName, cb);
		} else {
			handleMp4(client, url, outName, cb);
		}
	}

	function handleMp4(client:Client, url:String, outName:String, cb:CacheCallbacks) {
		final clientName = client.name;
		var lastSentRatio = 0.0;
		var canceled = false;
		downloadFile(client, url, outName, (downloaded, total) -> {
			if (canceled) return;
			final ratio = (downloaded / total).clamp(0, 1);
			if (ratio - lastSentRatio < 0.01 && ratio < 1) return;
			lastSentRatio = ratio;
			cb.onProgress(ratio.toFixed(4));
		}, () -> {
			if (canceled) return;
			probeDuration(outName, duration -> {
				if (canceled) return;
				if (duration > 0 && cb.onMetadata != null) cb.onMetadata(null, duration);
				cache.add(outName);
				cb.onComplete();
			});
		}, (err) -> {
			if (canceled) return;
			log(clientName, 'Mp4 download failed: $err');
			cb.onError();
		}, (cancel) -> {
			if (cb.registerCancel == null) return;
			cb.registerCancel(() -> {
				canceled = true;
				cancel();
			});
		});
	}

	function handleM3u8(client:Client, url:String, outName:String, cb:CacheCallbacks):Void {
		final clientName = client.name;
		final useProxy = main.config.enableProxy;
		var canceled = false;
		if (cb.registerCancel != null) cb.registerCancel(() -> canceled = true);
		downloadM3u8Playlist(client, url, useProxy, (playlist, totalSize, segments) -> {
			if (canceled) return;
			// only playlist file donwloaded
			if (useProxy) totalSize = playlist.length;

			if (!cache.removeOlderCache(totalSize + cache.freeSpaceBlock)) {
				log(clientName, cache.notEnoughSpaceErrorText);
				cb.onError();
				return;
			}

			if (useProxy) {
				File.saveContent('${cache.cacheDir}/$outName', playlist);
				cache.add(outName);
				cb.onComplete();
				return;
			}

			var activeDownloads = 0;
			final maxParallelDownloads = 10;
			var downloaded = 0;

			function downloadNextBatch():Void {
				for (segment in segments) {
					if (activeDownloads >= maxParallelDownloads) break;
					if (segment.started) continue;
					segment.started = true;
					activeDownloads++;
					trace("download segment", segment.i);

					downloadFile(client, segment.url, segment.name,
						(downloadedBytes, totalBytes) -> {},

						() -> {
							activeDownloads--;
							segment.completed = true;
							downloaded++;

							final progress = downloaded / segments.length;
							cb.onProgress(progress.clamp(0, 1));

							if (downloaded == segments.length) {
								trace('All ${downloaded}/${segments.length} segments downloaded');

								File.saveContent('${cache.cacheDir}/$outName', playlist);
								for (s in segments) cache.add(s.name);
								cache.add(outName);
								cb.onComplete();
							} else {
								downloadNextBatch();
							}
						},

						(err) -> {
							activeDownloads--;
							downloaded++;
							log(clientName, 'TS segment ${segment.i} download failed: $err');
							cb.onError();
							cleanupFiles(segments.map(item -> item.name));
						}
					);
				}
			}

			// Start the initial batch of downloads
			downloadNextBatch();
		}, (err) -> {
			log(clientName, 'M3U8 processing failed: $err');
			cb.onError();
		});
	}

	function request(url:String, ?options:Null<HttpsRequestOptions>, ?callback:Null<IncomingMessage->
		Void>):ClientRequest {
		final parsed = try new js.node.url.URL(url) catch (e) null;
		if (parsed == null || (parsed.protocol != "http:" && parsed.protocol != "https:")
			|| HttpProxy.isPrivateHost(parsed.hostname)) {
			throw 'Blocked or invalid URL: $url';
		}
		final httpsOptions:HttpsRequestOptions = options ?? {};
		// Allow self-signed certificates
		httpsOptions.rejectUnauthorized = false;
		httpsOptions.headers ??= {};
			(httpsOptions : Dynamic).lookup = HttpProxy.safeLookup;

		if (url.startsWith("https:")) {
			return Https.request(url, httpsOptions, callback);
		} else {
			return Http.request(url, httpsOptions, callback);
		}
	}

	function downloadM3u8Playlist(
		client:Client,
		url:String,
		useProxy:Bool,
		onSuccess:(playlist:String, totalSize:Int, segments:Array<Segment>) -> Void,
		onError:(err:String) -> Void
	) {
		final options:HttpsRequestOptions = {
			headers: {
				"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
				"Accept": "*/*",
			}
		};

		final req = try request(url, options, (res:IncomingMessage) -> {
			if (res.statusCode >= 300 && res.statusCode < 400) {
				final redirectUrl = res.headers.get("location");
				if (redirectUrl != null) {
					downloadM3u8Playlist(client, redirectUrl, useProxy, onSuccess, onError);
					return;
				}
			}

			final body:Array<Any> = [];
			res.on("data", chunk -> body.push(chunk));
			res.on("end", () -> {
				try {
					final buffer = Buffer.concat(body);
					final content = buffer.toString();
					if (!~/^#EXTM3U/.match(content)) {
						onError("Invalid M3U8 playlist");
						return;
					}

					final baseUrl = url.substring(0, url.lastIndexOf("/") + 1);
					final segments:Array<Segment> = [];

					final lines = content.split("\n");
					for (lineI => line in lines) {
						final line = line.trim();
						if (line.length == 0) continue;
						if (line.startsWith("#")) continue;
						final segmentUrl = !line.contains("://") ? baseUrl + line : line;
						final i = segments.length;
						final segment:Segment = {
							i: i,
							url: segmentUrl,
							started: false,
							completed: false,
							name: 'segment$i.ts',
						}
						segments.push(segment);
						lines[lineI] = './${segment.name}';
						if (useProxy) {
							lines[lineI] = '/proxy?url=${segmentUrl.urlEncode()}';
						}
					}
					if (segments.length == 0) {
						onError("No segments in M3U8 playlist");
						return;
					}
					if (useProxy) {
						onSuccess(lines.join("\n"), 0, segments);
						return;
					}

					// Head request can return full stream size, so lets do loose assumption
					final req = request(segments[0].url, {method: Get}, (res:IncomingMessage) -> {
						final contentLength = Std.parseInt(res.headers["content-length"]) ?? 0;
						res.destroy();
						final totalSize = contentLength * (segments.length + 1);
						if (totalSize == 0) {
							onError("Failed to get segment sizes: no content-length");
							return;
						}
						onSuccess(lines.join("\n"), totalSize, segments);
					});
					req.on("error", (err) -> {
						onError("Request error: failed to get segment sizes");
					});
					req.end();
				} catch (e) {
					onError('Playlist processing error: $e');
				}
			});
		}) catch (e) {
			onError('$e');
			return;
		};

		req.on("error", onError);
		req.end();
	}

	function downloadFile(
		client:Client, url:String, fileName:String,
		onProgress:(downloaded:Int, total:Int) -> Void,
		onComplete:() -> Void,
		onError:(err:String) -> Void,
		?onCancelable:(cancel:() -> Void)->Void
	):Void {
		final outPath = '${cache.cacheDir}/$fileName';
		final file = Fs.createWriteStream(outPath);
		final options:HttpsRequestOptions = {
			method: Get,
			headers: {
				"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
				"Accept": "*/*",
			}
		};
		final req = try request(url, options, (res:IncomingMessage) -> {
			final total = Std.parseInt(res.headers["content-length"]) ?? 0;
			var downloaded = 0;

			// Handle response data chunks
			res.on("data", (chunk) -> {
				downloaded += chunk.length;
				onProgress(downloaded, total);

				// Handle backpressure
				if (!file.write(chunk)) {
					res.pause();
					file.once("drain", () -> res.resume());
				}
			});

			// Handle response completion
			res.on("end", () -> file.end());

			// Handle response errors
			res.on("error", (err) -> {
				file.destroy();
				onError('Response error: $err');
			});
		}) catch (e) {
			file.destroy();
			if (FileSystem.exists(outPath)) FileSystem.deleteFile(outPath);
			onError('$e');
			return;
		};

		// Handle file write completion
		file.on("finish", onComplete);

		// Handle file system errors
		file.on("error", (err) -> {
			req.destroy();
			onError('File error: $err');
		});

		// Handle request errors
		req.on("error", (err) -> {
			file.destroy();
			onError('Request failed: $err');
		});

		if (onCancelable != null) onCancelable(() -> {
			req.destroy();
			file.destroy();
			if (FileSystem.exists(outPath)) FileSystem.deleteFile(outPath);
		});

		req.end();
	}

	function probeDuration(fileName:String, callback:(duration:Float) -> Void):Void {
		final path = '${cache.cacheDir}/$fileName';
		final args = [
			"-v", "error",
			"-show_entries", "format=duration",
			"-of", "default=noprint_wrappers=1:nokey=1",
			path
		];
		ChildProcess.execFile("ffprobe", args, (err, stdout, _) -> {
			if (err != null) {
				callback(0);
				return;
			}
			final duration = Std.parseFloat(Std.string(stdout).trim());
			callback(Math.isNaN(duration) ? 0 : duration);
		});
	}

	function cleanupFiles(files:Array<String>):Void {
		for (file in files) {
			final path = '${cache.cacheDir}/$file';
			if (FileSystem.exists(path)) FileSystem.deleteFile(path);
		}
	}

	function log(clientName:String, msg:String):Void {
		cache.logByName(clientName, msg);
	}
}
