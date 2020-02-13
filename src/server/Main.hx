package server;

import haxe.Timer;
import Client.ClientData;
import haxe.Json;
import js.Node.process;
import js.Node.__dirname;
import js.npm.ws.Server as WSServer;
import js.npm.ws.WebSocket;
import js.node.Http;
import js.node.Dns;
import Types;
using ClientTools;
using Lambda;

class Main {

	final wss:WSServer;
	final clients:Array<Client> = [];
	final videoList:Array<VideoItem> = [];
	final videoTimer = new VideoTimer();

	static function main():Void new Main();

	public function new(port = 4200, wsPort = 4201) {
		wss = new WSServer({port: wsPort});
		wss.on("connection", onConnect);
		function exit() {
			process.exit();
		}
		process.on("exit", exit);
		process.on("SIGINT", exit); // ctrl+c
		process.on("uncaughtException", (log) -> {
			trace(log);
		});
		process.on("unhandledRejection", (reason, promise) -> {
			trace("Unhandled Rejection at:", reason);
		});

		getPublicIp(ip -> {
			trace('Local: http://127.0.0.1:$port');
			trace('Global: http://$ip:$port');
		});

		final dir = '$__dirname/../res';
		HttpServer.init(dir);
		Lang.init('$dir/langs');

		Http.createServer((req, res) -> {
			HttpServer.serveFiles(req, res);
		}).listen(port);
	}

	function getPublicIp(callback:(ip:String)->Void):Void {
		Dns.resolve("google.com", function(err, arr) {
			if (err != null) {
				callback("ERROR " + err.code);
				return;
			}
			Http.get("http://myexternalip.com/raw", r -> {
				r.setEncoding("utf8");
				r.on("data", callback);
			});
		});
	}

	function onConnect(ws:WebSocket, req):Void {
		final ip = req.connection.remoteAddress;
		trace('Client connected ($ip)');
		final client = new Client(ws, "Unknown", false);
		clients.push(client);

		send(client, {
			type: Connected,
			connected: {
				isUnknownClient: true,
				clientName: client.name,
				clients: [
					for (client in clients) client.getData()
				],
				videoList: videoList
			}
		});
		sendClientList();

		ws.on("message", data -> {
			onMessage(client, Json.parse(data));
		});
		ws.on("close", err -> {
			trace('Client ${client.name} disconnected');
			clients.remove(client);
			sendClientList();
			if (client.isLeader) {
				if (videoTimer.isPaused()) videoTimer.play();
			}
		});
	}

	function onMessage(client:Client, data:WsEvent):Void {
		switch (data.type) {
			case Connected:
			case UpdateClients:
				sendClientList();
			case Login:
				final name = data.login.clientName;
				if (name.length == 0 || name.length > 20 || clients.getByName(name) != null) {
					send(client, {type: LoginError});
					return;
				}
				client.name = data.login.clientName;
				send(client, {
					type: data.type,
					login: {
						isUnknownClient: true,
						clientName: client.name,
						clients: clientList()
					}
				});
				sendClientList();
			case LoginError:
			case Logout:
				final oldName = client.name;
				client.name = "Unknown";
				send(client, {
					type: data.type,
					logout: {
						clientName: oldName,
						clients: clientList()
					}
				});
				sendClientList();
			case Message:
				// todo message log, max items
				// todo message max length check
				data.message.clientName = client.name;
				broadcast(data);
			case AddVideo:
				videoList.push(data.addVideo.item);
				broadcast(data);
				if (videoList.length == 1) {
					waitVideoStart = Timer.delay(startVideoPlayback, 3000);
				}
			case VideoLoaded:
				prepareVideoPlayback();
			case RemoveVideo:
				if (videoList.length == 0) return;
				final url = data.removeVideo.url;
				if (videoList[0].url == url) videoTimer.stop();
				videoList.remove(
					videoList.find(item -> item.url == url)
				);
				broadcast(data);
			case Pause:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.pause();
				broadcast(data);
			case Play:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.play();
				broadcast(data);
			case GetTime:
				if (videoList.length == 0) return;
				if (videoTimer.getTime() > videoList[0].duration) {
					videoTimer.stop();
					onMessage(client, {
						type: RemoveVideo,
						removeVideo: {
							url: videoList[0].url
						}
					});
					return;
				}
				send(client, {
					type: GetTime, getTime: {
					time: videoTimer.getTime(),
					paused: videoTimer.isPaused()
				}});
			case SetTime:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.setTime(data.setTime.time);
				broadcastExcept(client, data);
			case SetLeader:
				clients.setLeader(data.setLeader.clientName);
				sendClientList();
				if (videoList.length == 0) return;
				if (!clients.hasLeader()) {
					if (videoTimer.isPaused()) videoTimer.play();
					broadcast({
						type: Play, play: {
							time: videoTimer.getTime()
						}
					});
				}
		}
	}

	function clientList():Array<ClientData> {
		return [
			for (client in clients) client.getData()
		];
	}

	function sendClientList():Void {
		broadcast({
			type: UpdateClients,
			updateClients: {
				clients: clientList()
			}
		});
	}

	function send(client:Client, data:WsEvent):Void {
		client.ws.send(Json.stringify(data), null);
	}

	function broadcast(data:WsEvent):Void {
		final json = Json.stringify(data);
		for (client in clients) client.ws.send(json, null);
	}

	function broadcastExcept(skipped:Client, data:WsEvent):Void {
		final json = Json.stringify(data);
		for (client in clients) {
			if (client == skipped) continue;
			client.ws.send(json, null);
		}
	}

	var waitVideoStart:Timer;
	var loadedClientsCount = 0;

	function prepareVideoPlayback():Void {
		if (videoTimer.isStarted) return;
		loadedClientsCount++;
		if (loadedClientsCount == 1) {
			waitVideoStart = Timer.delay(startVideoPlayback, 3000);
		}
		if (loadedClientsCount >= clients.length) startVideoPlayback();
	}

	function startVideoPlayback():Void {
		if (waitVideoStart != null) waitVideoStart.stop();
		loadedClientsCount = 0;
		broadcast({type: VideoLoaded});
		videoTimer.start();
	}

}
