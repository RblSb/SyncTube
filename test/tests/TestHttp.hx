package test.tests;

import haxe.Json;
import js.node.Buffer;
import js.node.Fs.Fs;
import js.node.Http;
import js.node.Path as JsPath;
import js.node.http.IncomingMessage;
import server.HttpProxy;
import server.HttpServer;
import server.Main;
import sys.FileSystem;
import utest.Assert;
import utest.Async;
import utest.Test;

using Lambda;
using StringTools;

@:access(server)
class TestHttp extends Test {
	function testPrivateHostDetection() {
		// Local hostnames
		Assert.isTrue(HttpProxy.isPrivateHost("localhost"));
		Assert.isTrue(HttpProxy.isPrivateHost("LOCALHOST"));
		Assert.isTrue(HttpProxy.isPrivateHost("api.localhost"));
		Assert.isTrue(HttpProxy.isPrivateHost("printer.local"));

		// Private & reserved IPv4
		Assert.isTrue(HttpProxy.isPrivateHost("0.0.0.0"));
		Assert.isTrue(HttpProxy.isPrivateHost("10.0.0.1"));
		Assert.isTrue(HttpProxy.isPrivateHost("127.0.0.1"));
		Assert.isTrue(HttpProxy.isPrivateHost("169.254.169.254"));
		Assert.isTrue(HttpProxy.isPrivateHost("172.16.0.1"));
		Assert.isTrue(HttpProxy.isPrivateHost("172.31.255.255"));
		Assert.isTrue(HttpProxy.isPrivateHost("192.168.1.1"));
		Assert.isTrue(HttpProxy.isPrivateHost("100.64.0.1"));

		// Public IPv4 & domains
		Assert.isFalse(HttpProxy.isPrivateHost("example.com"));
		Assert.isFalse(HttpProxy.isPrivateHost("1.1.1.1"));
		Assert.isFalse(HttpProxy.isPrivateHost("8.8.8.8"));
		Assert.isFalse(HttpProxy.isPrivateHost("172.15.0.1"));
		Assert.isFalse(HttpProxy.isPrivateHost("172.32.0.1"));
		Assert.isFalse(HttpProxy.isPrivateHost("100.63.255.255"));

		// Private & loopback IPv6
		Assert.isTrue(HttpProxy.isPrivateHost("::1"));
		Assert.isTrue(HttpProxy.isPrivateHost("[::1]"));
		Assert.isTrue(HttpProxy.isPrivateHost("::"));
		Assert.isTrue(HttpProxy.isPrivateHost("fe80::1"));
		Assert.isTrue(HttpProxy.isPrivateHost("fc00::1"));
		Assert.isTrue(HttpProxy.isPrivateHost("fd12:3456:789a::1"));
		Assert.isTrue(HttpProxy.isPrivateHost("64:ff9b::1"));

		// IPv4-mapped IPv6 (dotted and WHATWG URL hex-normalized)
		Assert.isTrue(HttpProxy.isPrivateHost("::ffff:127.0.0.1"));
		Assert.isTrue(HttpProxy.isPrivateHost("[::ffff:7f00:1]"));
		Assert.isTrue(HttpProxy.isPrivateHost("::ffff:192.168.1.1"));
		Assert.isTrue(HttpProxy.isPrivateHost("[::ffff:c0a8:101]"));
		Assert.isFalse(HttpProxy.isPrivateHost("::ffff:93.184.216.34"));
		Assert.isFalse(HttpProxy.isPrivateHost("[::ffff:5db8:d822]"));
		Assert.isFalse(HttpProxy.isPrivateHost("2606:4700:4700::1111"));
	}

	function testMediaExtensionsAndUploadSanitization() {
		final dummyServer:HttpServer = cast Type.createEmptyInstance(HttpServer);
		for (ext in ["mp4", "webm", "wav", "mp3", "m4a", "flac", "ogg", "opus"]) {
			Assert.isTrue(dummyServer.isMediaExtension(ext), 'Expected $ext to be a media extension');
		}
		for (ext in ["html", "js", "svg", "json", "txt", "wasm", ""]) {
			Assert.isFalse(dummyServer.isMediaExtension(ext), 'Expected $ext not to be a media extension');
		}

		final fakeReq = (name:Null<String>) ->
			(cast {headers: {"content-name": name}} : IncomingMessage);

		Assert.equals("clip.mp4", dummyServer.getUploadName(fakeReq("clip%00.mp4")));
		Assert.equals("song.FLAC", dummyServer.getUploadName(fakeReq("song.FLAC")));
		Assert.equals("voice.opus", dummyServer.getUploadName(fakeReq("dir/voice.opus")));
		Assert.isNull(dummyServer.getUploadName(fakeReq("xss.html")));
		Assert.isNull(dummyServer.getUploadName(fakeReq("payload.svg")));
		Assert.isNull(dummyServer.getUploadName(fakeReq(".mp4")));
	}

	@:timeout(2000)
	function testSetupNullSafetyAndLocalization(async:Async) {
		final server = new Main({loadState: false});
		server.onServerInited = () -> {
			final baseUrl = 'http://${server.localIp}:${server.port}';

			// 1. Sending "null" body to /setup must return 400 and not crash
			rawRequest(baseUrl
				+ "/setup", "POST", {"content-type": "application/json"}, "null", (res, body) -> {
					Assert.equals(400, res.statusCode);
					final parsed:{success:Bool} = Json.parse(body);
					Assert.isFalse(parsed.success);

					// 2. Sending invalid setup with complex Accept-Language header uses "ru"
					final payload = Json.stringify({
						name: "admin",
						password: "1",
						passwordConfirmation: "2"
					});
					rawRequest(
						baseUrl + "/setup",
						"POST",
						{
							"content-type": "application/json",
							"accept-language": "RU-RU,ru;q=0.9,en-US;q=0.8"
						},
						payload,
						(res2, body2) -> {
							Assert.equals(400, res2.statusCode);
							final data:{
								success:Bool,
								errors:Array<{type:String, error:String}>
							} = Json.parse(body2);
							Assert.isFalse(data.success);
							Assert.isTrue(data.errors.length >= 2);
							final expectedRuMismatch = Lang.get("ru", "passwordsMismatchError");
							Assert.isTrue(data.errors.exists(e -> e.error == expectedRuMismatch));

							// 3. Valid admin setup succeeds, and subsequent GET /setup redirects cleanly
							final validPayload = Json.stringify({
								name: "admin",
								password: "password123",
								passwordConfirmation: "password123"
							});
							rawRequest(baseUrl
								+
								"/setup", "POST", {"content-type": "application/json"}, validPayload, (res3, body3) ->
								{
									Assert.equals(200, res3.statusCode);
									rawRequest(baseUrl + "/setup", "GET", {}, null, (res4, _) -> {
										Assert.equals(302, res4.statusCode);
										Assert.equals("/", res4.headers["location"]);
										Assert.isNull(res4.headers["content-type"]);
										async.done();
									});
								});
						}
					);
				});
		};
	}

	@:timeout(2000)
	function testConcurrentUploadReservationsAndStreaming(async:Async) {
		final server = new Main({loadState: false});
		server.onServerInited = () -> {
			final baseUrl = 'http://${server.localIp}:${server.port}';
			final chunkA = "0123456789abcdefghij"; // 20 bytes
			final chunkB = "ABCDEFGHIJ0123456789"; // 20 bytes

			// Two concurrent /upload-last-chunk calls with the same content-name must get distinct URLs
			rawRequest(
				baseUrl + "/upload-last-chunk",
				"POST",
				{"content-name": "clip.mp4"},
				chunkA,
				(res1, body1) -> {
					Assert.equals(200, res1.statusCode);
					final data1:{url:String} = Json.parse(body1);
					Assert.equals("/cache/clip.mp4", data1.url);

					rawRequest(
						baseUrl + "/upload-last-chunk",
						"POST",
						{"content-name": "clip.mp4"},
						chunkB,
						(res2, body2) -> {
							Assert.equals(200, res2.statusCode);
							final data2:{url:String} = Json.parse(body2);
							Assert.equals("/cache/clip2.mp4", data2.url);

							// Simulate in-progress upload for clip.mp4:
							// 10 bytes written on disk so far, 100 bytes total expected, last 20 bytes [80..99] in memory
							final filePath = JsPath.normalize(server.cache.getFilePath("clip.mp4"));
							Fs.writeFileSync(filePath, Buffer.from("FIRST_10_B"));
							@:privateAccess server.cache.add("clip.mp4");

							// Access the HttpServer instance via closure or test against a fresh HttpServer
							final httpServer = new HttpServer(server, {
								dir: '${server.rootDir}/res',
								customDir: '${server.userDir}/res',
								cache: server.cache
							});
							@:privateAccess httpServer.uploadingFilesSizes[filePath] = 100;
							@:privateAccess httpServer.uploadingFilesLastChunks[filePath] = Buffer.from(chunkA);

							final testSrv = Http.createServer(httpServer.serveFiles);
							testSrv.listen(0, "127.0.0.1", () -> {
								final port:Int = (testSrv.address() : Dynamic).port;
								final testUrl = 'http://127.0.0.1:$port/cache/clip.mp4';

								// 1. Sub-range inside tail chunk NOT ending at byte 99 (bytes=85-94) serves from memory buffer
								rawRequest(testUrl, "GET", {"range": "bytes=85-94"}, null, (rTail, bTail) ->
								{
									Assert.equals(206, rTail.statusCode);
									Assert.equals("bytes 85-94/100", rTail.headers["content-range"]);
									Assert.equals("10", rTail.headers["content-length"]);
									Assert.equals("56789abcde", bTail);

									// 2. Range starting at 0 (bytes=0-49) clamps to available disk bytes (0-9)
									rawRequest(testUrl, "GET", {"range": "bytes=0-49"}, null, (rHead, bHead) ->
									{
										Assert.equals(206, rHead.statusCode);
										Assert.equals("bytes 0-9/100", rHead.headers["content-range"]);
										Assert.equals("10", rHead.headers["content-length"]);
										Assert.equals("FIRST_10_B", bHead);

										// 3. Un-uploaded middle range (bytes=20-30) returns 416
										rawRequest(testUrl, "GET", {"range": "bytes=20-30"}, null, (rMid, _) ->
										{
											Assert.equals(416, rMid.statusCode);
											Assert.equals("bytes */100", rMid.headers["content-range"]);

											// 4. Request without range header clamps Content-Length to available disk bytes
											rawRequest(testUrl, "GET", {}, null, (rFull, bFull) -> {
												Assert.equals(200, rFull.statusCode);
												Assert.equals("10", rFull.headers["content-length"]);
												Assert.equals("FIRST_10_B", bFull);

												server.cache.remove("clip.mp4");
												testSrv.close(() -> async.done());
											});
										});
									});
								});
							});
						}
					);
				}
			);
		};
	}

	function testCacheStorageLimitFloatPrecision() {
		final server = new Main({loadState: false});
		final cache = server.cache;
		// Default storageLimit is 3 GB = 3221225472 bytes (would overflow 32-bit signed Int to -1073741824)
		Assert.isTrue(cache.storageLimit > 0);
		Assert.equals(3221225472.0, cache.storageLimit);

		// Setting limit above 2GB ensures Float arithmetic without wrapping
		cache.setStorageLimit(4.0 * 1024 * 1024 * 1024);
		Assert.equals(4294967296.0, cache.storageLimit);
		Assert.isTrue(cache.getFreeSpace() > 0);
	}

	@:timeout(2000)
	function testUploadBindsToReservedLastChunk(async:Async) {
		final server = new Main({loadState: false});
		server.onServerInited = () -> {
			final baseUrl = 'http://${server.localIp}:${server.port}';
			final chunk = "RESERVED_CHUNK_DATA";

			// 1. Reserve via /upload-last-chunk
			rawRequest(
				baseUrl + "/upload-last-chunk",
				"POST",
				{"content-name": "track.mp4"},
				chunk,
				(res1, body1) -> {
					Assert.equals(200, res1.statusCode);
					final data1:{url:String} = Json.parse(body1);
					Assert.equals("/cache/track.mp4", data1.url);

					// 2. Full upload with matching content-name must reuse track.mp4 (not create track2.mp4)
					final body = "0123456789";
					rawRequest(
						baseUrl + "/upload",
						"POST",
						{
							"content-name": "track.mp4",
							"content-length": '${body.length}'
						},
						body,
						(res2, _) -> {
							Assert.equals(200, res2.statusCode);
							Assert.isTrue(server.cache.isFileExists("track.mp4"));
							Assert.isFalse(server.cache.isFileExists("track2.mp4"));

							server.cache.remove("track.mp4");
							async.done();
						}
					);
				}
			);
		};
	}

	@:timeout(2000)
	function testProxyActiveRequestsAndQueryParamParsing(async:Async) {
		final server = new Main({loadState: false});
		server.onServerInited = () -> {
			final baseUrl = 'http://${server.localIp}:${server.port}';
			Assert.equals(0, HttpProxy.activeRequests);

			// Query where ?url= is not at start of query string, e.g. /proxy?debug=1&url=...
			rawRequest(baseUrl
				+ "/proxy?debug=1&url=http%3A%2F%2F127.0.0.1", "GET", {}, null, (res, _) -> {
					Assert.equals(400, res.statusCode);
					// activeRequests must not leak when proxyRequest returns false
					Assert.equals(0, HttpProxy.activeRequests);
					async.done();
				});
		};
	}

	@:timeout(2000)
	function testAllowedLocalFilesBoundedMemory(async:Async) {
		final server = new Main({loadState: false});
		final httpServer = new HttpServer(server, {
			dir: '${server.rootDir}/res',
			customDir: '${server.userDir}/res',
			cache: server.cache,
			allowLocalRequests: true
		});

		for (i in 0...HttpServer.MAX_LAST_CHUNKS) {
			@:privateAccess httpServer.allowedLocalFiles['/file$i.mp4'] = true;
		}
		Assert.equals(HttpServer.MAX_LAST_CHUNKS,
			@:privateAccess httpServer.allowedLocalFiles.count());

		final tempFile = JsPath.resolve("temp_local_media.mp4");
		Fs.writeFileSync(tempFile, Buffer.from("LOCAL_MEDIA"));

		final testSrv = Http.createServer(httpServer.serveFiles);
		testSrv.listen(0, "127.0.0.1", () -> {
			final port:Int = (testSrv.address() : Dynamic).port;
			rawRequest('http://127.0.0.1:$port$tempFile', "GET", {}, null, (res, _) -> {
				Assert.equals(200, res.statusCode);
				Assert.equals(1, @:privateAccess httpServer.allowedLocalFiles.count());
				Assert.isTrue(@:privateAccess httpServer.allowedLocalFiles.exists(tempFile));
				if (Fs.existsSync(tempFile)) Fs.unlinkSync(tempFile);
				testSrv.close(() -> async.done());
			});
		});
	}

	function rawRequest(
		url:String,
		method:String,
		headers:Dynamic,
		body:Null<String>,
		cb:(res:IncomingMessage, data:String) -> Void
	):Void {
		final parsed = new js.node.url.URL(url);
		final options:Dynamic = {
			hostname: parsed.hostname,
			port: Std.parseInt(parsed.port),
			path: parsed.pathname + parsed.search,
			method: method,
			headers: headers
		};
		final req = Http.request(options, (res:IncomingMessage) -> {
			res.setEncoding("utf8");
			final buf = new StringBuf();
			res.on("data", chunk -> buf.add(chunk));
			res.on("end", () -> cb(res, buf.toString()));
		});
		if (body != null) req.write(body);
		req.end();
	}
}
