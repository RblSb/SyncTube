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
import json2object.JsonParser;
import json2object.ErrorUtils;
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

	static inline var VIDEO_START_MAX_DELAY = 3000;
	static inline var VIDEO_SKIP_DELAY = 1000;
	final rootDir = '$__dirname/..';
	public final logsDir:String;
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
	final wsEventParser = new JsonParser<WsEvent>();
	final consoleInput:ConsoleInput;
	final videoList = new VideoList();
	final videoTimer = new VideoTimer();
	final messages:Array<Message> = [];
	final logger:Logger;
	var isPlaylistOpen = true;
	var itemPos = 0;

	static function main():Void new Main();

	function new() {
		verbose = Sys.args().has("--verbose");
		statePath = '$rootDir/user/state.json';
		logsDir = '$rootDir/user/logs';
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
		logger = new Logger(logsDir, 10, verbose);
		consoleInput = new ConsoleInput(this);
		consoleInput.initConsoleInput();
		initIntergationHandlers();
		loadState();
		config = loadUserConfig();
		userList = loadUsers();
		config.isVerbose = verbose;
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
		HttpServer.init(dir, '$rootDir/user/res', config.localAdmins);
		Lang.init('$dir/langs');

		final server = Http.createServer((req, res) -> {
			HttpServer.serveFiles(req, res);
		});
		wss = new WSServer({server: server});
		wss.on("connection", onConnect);
		server.listen(port);

		new Timer(25000).run = () -> {
			for (client in clients) {
				if (client.isAlive) {
					client.isAlive = false;
					client.ws.ping();
					continue;
				}
				client.ws.terminate();
				onMessage(client, {
					type: Disconnected
				}, true);
			}
		};
	}

	public function exit():Void {
		saveState();
		logger.saveLog();
		process.exit();
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
		Utils.ensureDir(folder);
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
		Utils.ensureDir(crashesFolder);
		final name = DateTools.format(Date.now(), "%Y-%m-%d_%H_%M_%S") + "-" + type;
		File.saveContent('$crashesFolder/$name.json', Json.stringify(data, "\t"));
	}

	function initIntergationHandlers():Void {
		// Prevent heroku idle when clients online (needs APP_URL env var)
		if (process.env["_"] != null && process.env["_"].contains("heroku")
			&& process.env["APP_URL"] != null) {
			var url = process.env["APP_URL"];
			if (!url.startsWith("http")) url = 'http://$url';
			new Timer(10 * 60 * 1000).run = function() {
				if (clients.length == 0) return;
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

	public function replayLog(events:Array<ServerEvent>):Void {
		final timer = new Timer(1000);
		timer.run = () -> {
			if (events.length == 0) {
				timer.stop();
				return;
			}
			final e = events.shift();
			switch (e.event.type) {
				case Connected:
					if (clients.getByName(e.clientName) == null) {
						final ws:Dynamic = {send: () -> {}};
						final id = freeIds.length > 0 ? freeIds.shift() : clients.length;
						final client = new Client(ws, null, id, e.clientName, e.clientGroup);
						ws.ping = () -> client.isAlive = true;
						clients.push(client);
					}
					onMessage(clients.getByName(e.clientName), e.event, true);
				case Login:
					final name = e.event.login.clientName;
					final hash = e.event.login.passHash;
					if (hash != null && !userList.admins.exists(a -> a.name == name)) {
						e.event.login.passHash = null;
					}
					onMessage(clients.getByName(e.clientName), e.event, true);
				default:
					onMessage(clients.getByName(e.clientName), e.event, true);
			}
		}
	}

	function onConnect(ws:WebSocket, req:IncomingMessage):Void {
		final ip = req.connection.remoteAddress;
		final id = freeIds.length > 0 ? freeIds.shift() : clients.length;
		final name = 'Guest ${id + 1}';
		trace('$name connected ($ip)');
		final isAdmin = config.localAdmins && req.connection.localAddress == ip;
		final client = new Client(ws, req, id, name, 0);
		client.isAdmin = isAdmin;
		clients.push(client);
		ws.on("pong", () -> client.isAlive = true);
		onMessage(client, {
			type: Connected
		}, true);

		ws.on("message", data -> {
			final obj = wsEventParser.fromJson(data);
			if (wsEventParser.errors.length > 0) {
				final line = 'Wrong request for type "${obj.type}":';
				final errorLines = ErrorUtils.convertErrorArray(wsEventParser.errors);
				final errors = '$line\n$errorLines';
				trace(errors);
				serverMessage(client, errors);
				return;
			}
			onMessage(client, obj, false);
		});

		ws.on("close", err -> {
			onMessage(client, {
				type: Disconnected
			}, true);
		});
	}

	function onMessage(client:Client, data:WsEvent, internal:Bool):Void {
		logger.log({
			clientName: client.name,
			clientGroup: client.group.toInt(),
			event: data,
			time: Date.now().getTime()
		});
		switch (data.type) {
			case Connected:
				if (!internal) return;
				if (clients.length == 1 && videoList.length > 0)
					if (videoTimer.isPaused()) videoTimer.play();

				send(client, {
					type: Connected,
					connected: {
						config: config,
						history: messages,
						isUnknownClient: true,
						clientName: client.name,
						clients: clientList(),
						videoList: videoList,
						isPlaylistOpen: isPlaylistOpen,
						itemPos: itemPos,
						globalIp: globalIp
					}
				});
				sendClientListExcept(client);

			case Disconnected:
				if (!internal) return;
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
				sendClientListExcept(client);

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
				sendClientListExcept(client);

			case Message:
				if (!checkPermission(client, WriteChatPerm)) return;
				var text = data.message.text;
				if (text.length == 0) return;
				if (text.length > config.maxMessageLength) {
					text = text.substr(0, config.maxMessageLength);
				}
				data.message.text = text;
				data.message.clientName = client.name;
				final time = Date.now().toString().split(" ")[1];
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
					broadcast(data);
					restartWaitTimer();
				} else {
					broadcast(data);
				}

			case SkipVideo:
				if (!checkPermission(client, RemoveVideoPerm)) return;
				skipVideo(data);

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
				final maxTime = videoList[itemPos].duration - 0.01;
				if (videoTimer.getTime() > maxTime) {
					videoTimer.pause();
					videoTimer.setTime(maxTime);
					final currentLength = videoList.length;
					final currentPos = itemPos;
					Timer.delay(() -> {
						if (videoList.length != currentLength) return;
						if (itemPos != currentPos) return;
						skipVideo({
							type: SkipVideo, skipVideo: {
								url: videoList[itemPos].url
							}
						});
					}, VIDEO_SKIP_DELAY);
					return;
				}
				final obj:WsEvent = {
					type: GetTime, getTime: {
						time: videoTimer.getTime()
					}
				};
				if (videoTimer.isPaused()) obj.getTime.paused = true;
				if (videoTimer.getRate() != 1) {
					if (!clients.hasLeader()) videoTimer.setRate(1);
					else obj.getTime.rate = videoTimer.getRate();
				}
				send(client, obj);

			case SetTime:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.setTime(data.setTime.time);
				broadcastExcept(client, data);

			case SetRate:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.setRate(data.setRate.rate);
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
					videoTimer.setRate(1);
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
				itemPos = videoList.setNextItem(pos, itemPos);
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

	function sendClientListExcept(skipped:Client):Void {
		broadcastExcept(skipped, {
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

	function skipVideo(data:WsEvent):Void {
		if (videoList.length == 0) return;
		final item = videoList[itemPos];
		if (item.url != data.skipVideo.url) return;
		itemPos = videoList.skipItem(itemPos);
		if (videoList.length > 0) restartWaitTimer();
		broadcast(data);
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
		waitVideoStart = Timer.delay(startVideoPlayback, VIDEO_START_MAX_DELAY);
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
