package test.tests;

import Types.WsEvent;
import Types.WsEventType;
import haxe.Json;
import haxe.Timer;
import js.lib.Promise;
import js.node.Http;
import js.npm.ws.WebSocket.WebSocket;
import server.Main;
import utest.Assert;
import utest.Async;
import utest.Test;

using StringTools;

@:access(server)
class TestServer extends Test {
	@:timeout(500)
	function testBadRequests(async:Async) {
		final server = new Main({loadState: false});
		server.onServerInited = () -> {
			final url = 'http://${server.localIp}:${server.port}';
			request('$url/你好，世界!@$^&*)_+-=', data -> {
				Assert.equals("File 你好，世界!@$^&*)_ -= not found.", data);
			});
			request('$url/Привет%00мир!', data -> {
				Assert.equals("File Приветмир! not found.", data);
			});
			request('$url/Ы%ы%00ы!', data -> {
				Assert.equals("<!DOCTYPE html>", splitLines(data)[0]);
			});
			request('$url/video/skins/default.php?dir_inc=/etc/passwd%00', data -> {
				var line = "File video/skins/default.php not found.";
				if (Sys.systemName() == "Windows") line = line.replace("/", "\\");
				Assert.equals(line, data);
			});
			request('$url/%20', data -> {
				Assert.equals("<!DOCTYPE html>", splitLines(data)[0]);
			});
			request('$url/build/../../server.js', data -> {
				Assert.equals("File server.js not found.", data);
			});
			request('$url/?meh', data -> {
				Assert.equals("<!DOCTYPE html>", splitLines(data)[0]);
				async.done();
			});
		}
	}

	function splitLines(text:String):Array<String> {
		return ~/\r?\n/g.split(text);
	}

	function request(url:String, onComplete:(data:String) -> Void):Void {
		Http.get(url, r -> {
			r.setEncoding("utf8");
			final data = new StringBuf();
			r.on("data", chunk -> data.add(chunk));
			r.on("end", _ -> onComplete(data.toString()));
		}).on("error", e -> trace(e));
	}

	@:timeout(2000)
	function testDoubleSkip(async:Async) {
		final server = new Main({loadState: false});
		server.onServerInited = () -> {
			final client = new FakeClient(server.localIp, server.port);
			var client2:FakeClient = null;
			// client.ws.on("message", data -> {
			// 	final data:WsEvent = Json.parse(data);
			// 	trace(data.type);
			// });

			client.message().then((data) -> {
				Assert.equals(Connected, data.type);
				Assert.equals(1, server.clients.length);
				client.name = data.connected.clientName;

				client2 = new FakeClient(server.localIp, server.port);
				client2.message().then(data -> {
					Assert.equals(Connected, data.type);
					client2.name = data.connected.clientName;
				});

				client.message();
			}).then(data -> {
				Assert.equals(UpdateClients, data.type);
				Assert.equals(2, server.clients.length);
				client.send({
					type: AddVideo,
					addVideo: {
						item: {
							url: "url1",
							title: "1",
							author: "",
							duration: 30,
							isTemp: true,
							isIframe: false
						},
						atEnd: true
					}
				});
			}).then(data -> {
				Assert.equals(AddVideo, data.type);
				client2.send({type: VideoLoaded});
				client.send({type: VideoLoaded});
			}).then(data -> {
				Assert.equals(VideoLoaded, data.type);
				client.send({
					type: SetLeader,
					setLeader: {
						clientName: client.name
					},
				});
			}).then(data -> {
				Assert.equals(SetLeader, data.type);
				client.send({
					type: SetTime,
					setTime: {
						time: 30
					},
				});
				// SetTime will not answer to leader request
				// wait for second client data
				client2.messages(2);
			}).then(arr -> {
				Assert.equals(SetLeader, arr[0].type);
				Assert.equals(SetTime, arr[1].type);
				client.send({
					type: SetLeader,
					setLeader: {
						clientName: ""
					}
				});
			}).then(data -> {
				Assert.equals(SetLeader, data.type);
				Timer.delay(() -> {
					client2.send({type: GetTime});
					client2.send({
						type: AddVideo,
						addVideo: {
							item: {
								url: "url2",
								title: "2",
								author: "",
								duration: 30,
								isTemp: true,
								isIframe: false
							},
							atEnd: true
						}
					});
				}, 50);
				client.send({type: GetTime});
			}).then(data -> {
				Assert.equals(AddVideo, data.type);
				client.message(); // single skip after 1s
			}).then(data -> {
				Assert.equals(SkipVideo, data.type);
				Assert.equals(1, server.videoList.length);
				Assert.equals("url2", server.videoList.getItem(0).url);
				Timer.delay(() -> {
					client.send({
						type: Message,
						message: {
							clientName: "",
							text: "ok"
						}
					});
				}, 50);
				client.message();
			}).then(data -> {
				Assert.equals(Message, data.type);
				async.done();
			});
		}
	}
}

class FakeClient {
	public final ws:WebSocket;
	public var name = "Unknown";

	public function new(ip:String, port:Int) {
		ws = new WebSocket('ws://$ip:$port');
	}

	public function open() {
		final promise = new Promise((resolve, reject) -> {
			ws.once("open", _ -> resolve(_));
			ws.once("error", err -> reject(err));
		});
		return promise;
	}

	// Warning: promise chain skips several fast sent messages
	public function message() {
		final promise = new Promise((resolve, reject) -> {
			ws.once("message", data -> {
				final data:WsEvent = Json.parse(data);
				resolve(data);
			});
		});
		return promise;
	}

	public function messages(count:Int) {
		var arr:Array<WsEvent> = [];
		final promise = new Promise((resolve, reject) -> {
			function onMessage(data:String):Void {
				final data:WsEvent = Json.parse(data);
				arr.push(data);
				count--;
				if (count == 0) {
					ws.off("message", onMessage);
					resolve(arr);
				}
			}
			ws.on("message", onMessage);
		});
		return promise;
	}

	public function send(data:WsEvent) {
		ws.send(Json.stringify(data), null);
		return message();
	}

	public function wait(ms:Int) {
		final promise = new Promise((resolve, reject) -> {
			Timer.delay(() -> resolve(null), ms);
		});
		return promise;
	}
}
