package server;

import haxe.crypto.Sha256;
import sys.FileSystem;
import sys.io.File;
import haxe.Timer;
import haxe.Json;
import js.Node.process;
import js.Node.__dirname;
import js.npm.ws.Server as WSServer;
import js.npm.ws.WebSocket;
import js.node.http.IncomingMessage;
import js.node.Http;
import Client.ClientData;
import Types.Config;
import Types.Permission;
import Types.UserList;
import Types.Message;
import Types.WsEvent;
using StringTools;
using ClientTools;
using Lambda;

class Main {

	final rootDir = '$__dirname/..';
	final verbose:Bool;
	final statePath:String;
	final wss:WSServer;
	final localIp:String;
	var globalIp:String;
	final port:Int;
	public final config:Config;
	final userList:UserList;
	final clients:Array<Client> = [];
	final freeIds:Array<Int> = [];
	final consoleInput:ConsoleInput;
	final videoList = new VideoList();
	final videoTimer = new VideoTimer();
	final messages:Array<Message> = [];
	var isPlaylistOpen = true;
	var itemPos = 0;

	static function main():Void new Main();

	function new() {
		verbose = Sys.args().has("--verbose");
		statePath = '$rootDir/user/state.json';
		// process.on("exit", exit);
		process.on("SIGINT", exit); // ctrl+c
		process.on("SIGUSR1", exit); // kill pid
		process.on("SIGUSR2", exit);
		process.on("SIGTERM", exit);
		process.on("uncaughtException", err -> {
			logError("uncaughtException", {
				message: err.message,
				stack: err.stack
			});
			exit();
		});
		process.on("unhandledRejection", (reason, promise) -> {
			logError("unhandledRejection", reason);
			exit();
		});
		consoleInput = new ConsoleInput(this);
		consoleInput.initConsoleInput();
		initIntergationHandlers();
		loadState();
		config = loadUserConfig();
		userList = loadUsers();
		config.salt = generateConfigSalt();
		localIp = Utils.getLocalIp();
		globalIp = localIp;
		port = config.port;
		final envPort = (process.env : Dynamic).PORT;
		if (envPort != null) port = envPort;

		Utils.getGlobalIp(ip -> {
			globalIp = ip;
			trace('Local: http://$localIp:$port');
			trace('Global: http://$globalIp:$port');
		});

		final dir = '$rootDir/res';
		HttpServer.init(dir, '$rootDir/user/res');
		Lang.init('$dir/langs');

		final server = Http.createServer((req, res) -> {
			HttpServer.serveFiles(req, res);
		});
		server.listen(port);
		wss = new WSServer({server: server});
		wss.on("connection", onConnect);
	}

	public function exit():Void {
		saveState();
		if (wss == null) {
			process.exit();
			return;
		}
		wss.close(() -> process.exit());
	}

	function generateConfigSalt():String {
		if (userList.salt == null)
			userList.salt = Sha256.encode('${Math.random()}');
		return userList.salt;
	}

	function loadUserConfig():Config {
		final config = getUserConfig();
		inline function getPermissions(type:Permission):Array<Permission> {
			return Reflect.field(config.permissions, cast type);
		}
		final groups = [GuestPerm, UserPerm, LeaderPerm, AdminPerm];
		for (field in groups) {
			final group = getPermissions(field);
			for (type in groups) {
				if (type == field) continue;
				if (group.indexOf(type) == -1) continue;
				group.remove(type);
				for (item in getPermissions(type)) group.push(item);
			}
		}
		return config;
	}

	function getUserConfig():Config {
		final config:Config = Json.parse(File.getContent('$rootDir/default-config.json'));
		final customPath = '$rootDir/user/config.json';
		if (!FileSystem.exists(customPath)) return config;
		final customConfig:Config = Json.parse(File.getContent(customPath));
		for (field in Reflect.fields(customConfig)) {
			if (Reflect.field(config, field) == null) trace('Warning: config field "$field" is unknown');
			Reflect.setField(config, field, Reflect.field(customConfig, field));
		}
		final emoteCopies:Map<String, Bool> = [];
		for (emote in config.emotes) {
			if (emoteCopies[emote.name]) trace('Warning: emote name "${emote.name}" has copy');
			emoteCopies[emote.name] = true;
			if (!verbose) continue;
			if (emoteCopies[emote.image]) trace('Warning: emote url of name "${emote.name}" has copy');
			emoteCopies[emote.image] = true;
		}
		return config;
	}

	function loadUsers():UserList {
		final customPath = '$rootDir/user/users.json';
		if (!FileSystem.exists(customPath)) return {
			admins: []
		};
		return Json.parse(File.getContent(customPath));
	}

	function writeUsers(users:UserList):Void {
		final folder = '$rootDir/user';
		if (!FileSystem.exists(folder)) {
			FileSystem.createDirectory(folder);
		}
		final data = Json.stringify(users, "\t");
		File.saveContent('$folder/users.json', data);
	}

	function saveState():Void {
		trace("Saving state...");
		final data:ServerState = {
			videoList: videoList,
			isPlaylistOpen: isPlaylistOpen,
			itemPos: itemPos,
			messages: messages,
			timer: {
				time: videoTimer.getTime(),
				paused: videoTimer.isPaused()
			}
		}
		final json = Json.stringify(data, "\t");
		File.saveContent(statePath, json);
	}

	function loadState():Void {
		if (!FileSystem.exists(statePath)) return;
		trace("Loading state...");
		final data:ServerState = Json.parse(File.getContent(statePath));
		videoList.resize(0);
		messages.resize(0);
		for (item in data.videoList) videoList.push(item);
		isPlaylistOpen = data.isPlaylistOpen;
		itemPos = data.itemPos;
		for (message in data.messages) messages.push(message);
		videoTimer.start();
		videoTimer.setTime(data.timer.time);
		videoTimer.pause();
	}

	function logError(type:String, data:Dynamic):Void {
		trace(type, data);
		final crashesFolder = '$rootDir/user/crashes';
		if (!FileSystem.exists(crashesFolder)) FileSystem.createDirectory(crashesFolder);
		final name = DateTools.format(Date.now(), "%Y-%m-%d_%H_%M_%S") + "-" + type;
		File.saveContent('$crashesFolder/$name.json', Json.stringify(data, "\t"));
	}

	function initIntergationHandlers():Void {
		// Prevent heroku idle when clients online (needs APP_URL env var)
		if (process.env["_"] != null && process.env["_"].contains("heroku")
			&& process.env["APP_URL"] != null) {
			new Timer(10 * 60 * 1000).run = function() {
				if (clients.length == 0) return;
				final url = 'http://${process.env["APP_URL"]}';
				trace('Ping $url');
				Http.get(url, r -> {});
			}
		}
	}

	public function addAdmin(name:String, password:String):Void {
		password += config.salt;
		final hash = Sha256.encode(password);
		if (userList.admins == null) userList.admins = [];
		userList.admins.push({
			name: name,
			hash: hash
		});
		writeUsers(userList);
		trace('Admin $name added.');
	}

	function onConnect(ws:WebSocket, req:IncomingMessage):Void {
		final ip = req.connection.remoteAddress;
		final id = freeIds.length > 0 ? freeIds.shift() : clients.length;
		final name = 'Guest ${id + 1}';
		trace('$name connected ($ip)');
		final isAdmin = req.connection.localAddress == ip;
		final client = new Client(ws, req, id, name, 0);
		client.isAdmin = isAdmin;
		clients.push(client);
		if (clients.length == 1 && videoList.length > 0)
			if (videoTimer.isPaused()) videoTimer.play();

		send(client, {
			type: Connected,
			connected: {
				config: config,
				history: messages,
				isUnknownClient: true,
				clientName: client.name,
				clients: [
					for (client in clients) client.getData()
				],
				videoList: videoList,
				isPlaylistOpen: isPlaylistOpen,
				itemPos: itemPos,
				globalIp: globalIp
			}
		});
		sendClientList();

		ws.on("message", data -> {
			onMessage(client, Json.parse(data));
		});
		ws.on("close", err -> {
			trace('Client ${client.name} disconnected');
			Utils.sortedPush(freeIds, client.id);
			clients.remove(client);
			sendClientList();
			if (client.isLeader) {
				if (videoTimer.isPaused()) videoTimer.play();
			}
			if (clients.length == 0) {
				if (waitVideoStart != null) waitVideoStart.stop();
				videoTimer.pause();
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
				if (badNickName(name) || name.length > config.maxLoginLength
					|| clients.getByName(name) != null) {
					serverMessage(client, "usernameError");
					send(client, {type: LoginError});
					return;
				}
				final hash = data.login.passHash;
				if (hash == null) {
					if (userList.admins.exists(a -> a.name == name)) {
						send(client, {type: PasswordRequest});
						return;
					}
				} else {
					if (userList.admins.exists(
						a -> a.name == name && a.hash == hash
					)) client.isAdmin = true;
					else {
						serverMessage(client, "passwordMatchError");
						send(client, {type: LoginError});
						return;
					}
				}
				client.name = name;
				client.isUser = true;
				send(client, {
					type: data.type,
					login: {
						isUnknownClient: true,
						clientName: client.name,
						clients: clientList()
					}
				});
				sendClientList();

			case PasswordRequest:
			case LoginError:
			case Logout:
				final oldName = client.name;
				final id = clients.indexOf(client) + 1;
				client.name = 'Guest $id';
				client.isUser = false;
				send(client, {
					type: data.type,
					logout: {
						oldClientName: oldName,
						clientName: client.name,
						clients: clientList()
					}
				});
				sendClientList();

			case Message:
				if (!checkPermission(client, WriteChatPerm)) return;
				var text = data.message.text;
				if (text.length == 0) return;
				if (text.length > config.maxMessageLength) {
					text = text.substr(0, config.maxMessageLength);
				}
				data.message.text = text;
				data.message.clientName = client.name;
				final time = "[" + Date.now().toString().split(" ")[1] + "] ";
				messages.push({text: text, name: client.name, time: time});
				if (messages.length > config.serverChatHistory) messages.shift();
				broadcast(data);

			case ServerMessage:
			case AddVideo:
				if (!checkPermission(client, AddVideoPerm)) return;
				if (!isPlaylistOpen) {
					if (!checkPermission(client, LockPlaylistPerm)) return;
				}
				if (config.totalVideoLimit != 0
					&& videoList.length >= config.totalVideoLimit) {
					serverMessage(client, "totalVideoLimitError");
					return;
				}
				if (config.userVideoLimit != 0
					&& videoList.itemsByUser(client) >= config.userVideoLimit) {
					serverMessage(client, "videoLimitPerUserError");
					return;
				}
				final item = data.addVideo.item;
				item.author = client.name;
				final local = '$localIp:$port';
				if (item.url.contains(local)) {
					item.url = item.url.replace(local, '$globalIp:$port');
				}
				if (videoList.exists(i -> i.url == item.url)) {
					serverMessage(client, "videoAlreadyExistsError");
					return;
				}
				videoList.addItem(item, data.addVideo.atEnd, itemPos);
				broadcast(data);
				// Initial timer start if VideoLoaded is not happen
				if (videoList.length == 1) restartWaitTimer();

			case VideoLoaded:
				// Called if client loads next video and can play it
				prepareVideoPlayback();

			case RemoveVideo:
				if (!checkPermission(client, RemoveVideoPerm)) return;
				if (videoList.length == 0) return;
				final url = data.removeVideo.url;
				var index = videoList.findIndex(item -> item.url == url);
				if (index == -1) return;

				final isCurrent = videoList[itemPos].url == url;
				itemPos = videoList.removeItem(index, itemPos);
				if (isCurrent && videoList.length > 0) {
					restartWaitTimer();
				}
				broadcast(data);

			case SkipVideo:
				if (!checkPermission(client, RemoveVideoPerm)) return;
				if (videoList.length == 0) return;
				final item = videoList[itemPos];
				if (item.url != data.skipVideo.url) return;
				itemPos = videoList.skipItem(itemPos);
				if (videoList.length > 0) restartWaitTimer();
				broadcast(data);

			case Pause:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.setTime(data.pause.time);
				videoTimer.pause();
				broadcast(data);

			case Play:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.setTime(data.play.time);
				videoTimer.play();
				broadcast(data);

			case GetTime:
				if (videoList.length == 0) return;
				if (videoTimer.getTime() > videoList[itemPos].duration) {
					videoTimer.stop();
					onMessage(client, {
						type: SkipVideo, skipVideo: {
							url: videoList[itemPos].url
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

			case Rewind:
				if (!checkPermission(client, RewindPerm)) return;
				if (videoList.length == 0) return;
				data.rewind.time += videoTimer.getTime();
				if (data.rewind.time < 0) data.rewind.time = 0;
				videoTimer.setTime(data.rewind.time);
				broadcast(data);

			case SetLeader:
				final clientName = data.setLeader.clientName;
				if (client.name == clientName) {
					if (!checkPermission(client, RequestLeaderPerm)) return;
				} else if (!client.isLeader && clientName != "") {
					if (!checkPermission(client, SetLeaderPerm)) return;
				}
				clients.setLeader(clientName);
				broadcast({
					type: SetLeader, setLeader: {
						clientName: clientName
					}
				});
				if (videoList.length == 0) return;
				if (!clients.hasLeader()) {
					if (videoTimer.isPaused()) videoTimer.play();
					broadcast({
						type: Play, play: {
							time: videoTimer.getTime()
						}
					});
				}

			case PlayItem:
				if (!checkPermission(client, ChangeOrderPerm)) return;
				itemPos = data.playItem.pos;
				restartWaitTimer();
				broadcast(data);

			case SetNextItem:
				if (!checkPermission(client, ChangeOrderPerm)) return;
				final pos = data.setNextItem.pos;
				if (pos == itemPos || pos == itemPos + 1) return;
				videoList.setNextItem(pos, itemPos);
				broadcast(data);

			case ToggleItemType:
				final pos = data.toggleItemType.pos;
				videoList.toggleItemType(pos);
				broadcast(data);

			case ClearChat:
				if (!checkPermission(client, ClearChatPerm)) return;
				messages.resize(0);
				broadcast(data);

			case ClearPlaylist:
				if (!checkPermission(client, RemoveVideoPerm)) return;
				videoTimer.stop();
				videoList.resize(0);
				itemPos = 0;
				broadcast(data);

			case ShufflePlaylist:
				if (!checkPermission(client, ChangeOrderPerm)) return;
				if (videoList.length == 0) return;
				final current = videoList[itemPos];
				videoList.remove(current);
				Utils.shuffle(videoList);
				videoList.insert(itemPos, current);
				broadcast({
					type: UpdatePlaylist,
					updatePlaylist: {
					videoList: videoList
				}});

			case UpdatePlaylist:
				broadcast({
					type: UpdatePlaylist,
					updatePlaylist: {
					videoList: videoList
				}});

			case TogglePlaylistLock:
				if (!checkPermission(client, LockPlaylistPerm)) return;
				isPlaylistOpen = !isPlaylistOpen;
				broadcast({
					type: TogglePlaylistLock,
					togglePlaylistLock: {
						isOpen: isPlaylistOpen
					}
				});
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

	function serverMessage(client:Client, textId:String):Void {
		send(client, {
			type: ServerMessage, serverMessage: {
				textId: textId
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

	function checkPermission(client:Client, perm:Permission):Bool {
		final state = hasPermission(client, perm);
		if (!state) send(client, {
			type: ServerMessage, serverMessage: {
				textId: "accessError"
			}
		});
		return state;
	}

	function hasPermission(client:Client, perm:Permission):Bool {
		final p = config.permissions;
		if (client.isAdmin) return p.admin.indexOf(cast perm) != -1;
		if (client.isLeader) return p.leader.indexOf(cast perm) != -1;
		if (client.isUser) return p.user.indexOf(cast perm) != -1;
		return p.guest.indexOf(cast perm) != -1;
	}

	final htmlChars = ~/[&^<>'"]/;

	public function badNickName(name:String):Bool {
		if (name.length == 0) return true;
		if (htmlChars.match(name)) return true;
		return false;
	}

	var waitVideoStart:Timer;
	var loadedClientsCount = 0;

	function restartWaitTimer():Void {
		videoTimer.stop();
		if (waitVideoStart != null) waitVideoStart.stop();
		waitVideoStart = Timer.delay(startVideoPlayback, 3000);
	}

	function prepareVideoPlayback():Void {
		if (videoTimer.isStarted) return;
		loadedClientsCount++;
		if (loadedClientsCount == 1) restartWaitTimer();
		if (loadedClientsCount >= clients.length) startVideoPlayback();
	}

	function startVideoPlayback():Void {
		if (waitVideoStart != null) waitVideoStart.stop();
		loadedClientsCount = 0;
		broadcast({type: VideoLoaded});
		videoTimer.start();
	}

}
