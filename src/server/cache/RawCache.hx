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

	public function cacheRawVideo(client:Client, url:String, callback:(name:String) -> Void) {
		final isM3U8 = url.contains(".m3u8");
		final ext = isM3U8 ? "m3u8" : "mp4";

		final matchName = ~/^([^:.]+)\.(.+)/;
		final decodedUrl = try url.urlDecode() catch (e) url;
		final lastPart = decodedUrl.substr(decodedUrl.lastIndexOf("/") + 1);
		var outName = matchName.match(lastPart) ? matchName.matched(1)
			+ '.$ext' : 'video.$ext';
		outName = cache.getFreeFileName(outName);

		if (cache.exists(outName)) {
			callback(outName);
			return;
		}

		trace('Caching $url to $outName...');
		main.send(client, {
			type: Progress,
			progress: {
				type: Caching,
				ratio: 0,
				data: outName
			}
		});

		if (isM3U8) {
			handleM3u8(client, url, outName, callback);
		} else {
			handleMp4(client, url, outName, callback);
		}
	}

	function handleMp4(client:Client, url:String, outName:String, callback:(name:String) -> Void) {
		final clientName = client.name;
		downloadFile(client, url, outName, (downloaded, total) -> {
			main.sendByName(clientName, {
				type: Progress,
				progress: {
					type: Downloading,
					ratio: (downloaded / total).clamp(0, 1).toFixed(4)
				}
			});
		}, () -> {
			cache.add(outName);
			callback(outName);
		}, (err) -> {
			log(clientName, 'Mp4 download failed: $err');
			cancelProgress(clientName);
		});
	}

	function handleM3u8(client:Client, url:String, outName:String, callback:(name:String) -> Void):Void {
		final clientName = client.name;
		final useProxy = true;
		downloadM3u8Playlist(client, url, useProxy, (playlist, totalSize, segments) -> {
			// only playlist file donwloaded
			if (useProxy) totalSize = playlist.length;

			if (!cache.removeOlderCache(totalSize + cache.freeSpaceBlock)) {
				log(clientName, cache.notEnoughSpaceErrorText);
				cancelProgress(clientName);
				return;
			}

			if (useProxy) {
				main.sendByName(clientName, {
					type: Progress,
					progress: {
						type: Caching,
						ratio: 1,
						data: outName
					}
				});
				File.saveContent('${cache.cacheDir}/$outName', playlist);
				cache.add(outName);
				callback(outName);
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
							main.sendByName(clientName, {
								type: Progress,
								progress: {
									type: Downloading,
									ratio: progress.clamp(0, 1)
								}
							});

							if (downloaded == segments.length) {
								trace('All ${downloaded}/${segments.length} segments downloaded');

								File.saveContent('${cache.cacheDir}/$outName', playlist);
								cache.add(outName);
								callback(outName);
								// buildTsFiles(
								// 	segments.map(item -> item.name),
								// 	outName,
								// 	client,
								// 	callback
								// );
							} else {
								downloadNextBatch();
							}
						},

						(err) -> {
							activeDownloads--;
							downloaded++;
							log(clientName, 'TS segment ${segment.i} download failed: $err');
							cancelProgress(clientName);
							cleanupFiles(segments.map(item -> item.name));
						}
					);
				}
			}

			// Start the initial batch of downloads
			downloadNextBatch();
		}, (err) -> {
			log(clientName, 'M3U8 processing failed: $err');
			cancelProgress(clientName);
		});
	}

	function request(url:String, ?options:Null<HttpsRequestOptions>, ?callback:Null<IncomingMessage->
		Void>):ClientRequest {
		final httpsOptions:HttpsRequestOptions = options ?? {};
		// Allow self-signed certificates
		httpsOptions.rejectUnauthorized = false;
		httpsOptions.headers ??= {};

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

		final req = request(url, options, (res:IncomingMessage) -> {
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
							lines[lineI] = '/proxy?url=$segmentUrl';
						}
					}

					// Head request can return full stream size, so lets do loose assumption
					final req = request(segments[0].url, {method: Get}, (res:IncomingMessage) -> {
						final contentLength = Std.parseInt(res.headers["content-length"]) ?? 0;
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
		});

		req.on("error", onError);
		req.end();
	}

	function downloadFile(
		client:Client, url:String, fileName:String,
		onProgress:(downloaded:Int, total:Int) -> Void,
		onComplete:() -> Void,
		onError:(err:String) -> Void
	):Void {
		final outPath = '${cache.cacheDir}/$fileName';
		final file = Fs.createWriteStream(outPath);
		final options:HttpsRequestOptions = {
			method: Get,
			headers: {
				"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537." +
				Std.random(100),
				"Accept": "*/*",
			}
		};
		final req = request(url, options, (res:IncomingMessage) -> {
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
		});

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

		req.end();
	}

	function buildTsFiles(tempFiles:Array<String>, outName:String, client:Client, callback:String->Void) {
		final clientName = client.name;
		final missingFiles = tempFiles.filter(f ->
			!FileSystem.exists('${cache.cacheDir}/$f'));
		if (missingFiles.length > 0) {
			log(clientName, 'Concatenation failed: ${missingFiles.length} segments are missing');
			cancelProgress(clientName);
			cleanupFiles(tempFiles);
			return;
		}

		// Create concat file with absolute paths and proper escaping
		final concatFile = 'concat_list.txt';
		final concatContent = tempFiles.map(f -> {
			final path = './$f';
			return 'file \'${path}\'';
		}).join("\n");

		File.saveContent('${cache.cacheDir}/$concatFile', concatContent);

		// Prepare FFmpeg args with proper bitstream filters for TS files
		final args = [
			"-y", // Overwrite output without asking
			"-f", "concat", // Use concat format
			"-safe", "0", // Allow absolute paths
			"-i", concatFile, // Input file list
			"-c", "copy", // Copy streams without re-encoding
			"-bsf:a", "aac_adtstoasc", // Fix AAC audio streams from TS files
			"-movflags", "+faststart", // Optimize for web streaming
			outName // Output filename
		];

		trace('Executing FFmpeg with args: ${args.join(" ")}');

		// Create process with proper error capturing
		final process = ChildProcess.spawn("ffmpeg", args, {
			cwd: cache.cacheDir,
			// stderr: "pipe" // Capture stderr for error reporting
		});

		final errorOutput:Array<Buffer> = [];
		process.stderr.on("data", (data) -> errorOutput.push(data));

		// Set a reasonable timeout
		final timeout = 5 * 60 * 1000; // 5 minutes
		final timeoutId = js.Node.setTimeout(() -> {
			process.kill();
			log(clientName, 'FFmpeg process timed out after ${timeout / 1000} seconds');
			cancelProgress(clientName);
			cleanupFiles(tempFiles.concat([concatFile]));
		}, timeout);

		process.on("close", (code:Int) -> {
			js.Node.clearTimeout(timeoutId);

			if (code != 0) {
				final errorMsg = Buffer.concat(errorOutput).toString();
				cache.logWithAdmins(client, 'FFmpeg concatenation failed with code $code');
				final ffmpegErr = 'FFmpeg error output: $errorMsg';
				trace(ffmpegErr);

				// Log detailed error to admins
				final admins = main.clients.filter(client -> client.isAdmin);
				for (admin in admins) main.serverMessage(admin, ffmpegErr);

				main.send(client, {
					type: Progress,
					progress: {
						type: Canceled,
						ratio: 1
					}
				});
			} else {
				// Verify the output file exists and has content
				if (FileSystem.exists('${cache.cacheDir}/$outName')
					&& FileSystem.stat('${cache.cacheDir}/$outName').size > 0) {
					cache.add(outName);
					callback(outName);
				} else {
					log(clientName, 'FFmpeg process completed but output file is missing or empty');
					main.send(client, {
						type: Progress,
						progress: {
							type: Canceled,
							ratio: 1
						}
					});
				}
			}

			// Clean up temporary files after everything is done
			cleanupFiles(tempFiles.concat([concatFile]));
		});

		// Handle process errors (like if FFmpeg isn't found)
		process.on("error", (err) -> {
			js.Node.clearTimeout(timeoutId);
			log(clientName, 'Failed to start FFmpeg: $err');
			main.send(client, {
				type: Progress,
				progress: {
					type: Canceled,
					ratio: 1
				}
			});
			cleanupFiles(tempFiles.concat([concatFile]));
		});
	}

	function cleanupFiles(files:Array<String>):Void {
		for (file in files) {
			if (FileSystem.exists(file)) FileSystem.deleteFile(file);
		}
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
