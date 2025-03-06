package server;

import Client.ClientData;
import Types.Config;
import Types.FlashbackItem;
import Types.Message;
import Types.Permission;
import Types.PlayerType;
import Types.UserList;
import Types.VideoItem;
import Types.WsEvent;
import haxe.Json;
import haxe.Timer;
import haxe.crypto.Sha256;
import js.Node.__dirname;
import js.Node.process;
import js.node.Crypto;
import js.node.Http;
import js.node.http.IncomingMessage;
import js.node.url.URL;
import js.npm.ws.Server as WSServer;
import js.npm.ws.WebSocket;
import json2object.ErrorUtils;
import json2object.JsonParser;
import sys.FileSystem;
import sys.io.File;

private typedef MainOptions = {
	loadState:Bool
}

class Main {
	static inline var VIDEO_START_MAX_DELAY = 3000;
	static inline var VIDEO_SKIP_DELAY = 1000;
	static inline var FLASHBACKS_COUNT = 50;
	static inline var FLASHBACK_DIST = 30;
	static inline var EMPTY_ROOM_CALLBACK_DELAY = 5000;

	final rootDir = '$__dirname/..';

	public final userDir:String;
	public final logsDir:String;
	public final config:Config;

	final isNoState:Bool;
	final verbose:Bool;
	final statePath:String;
	var wss:WSServer;
	final localIp:String;
	var globalIp:String;
	final playersCacheSupport:Array<PlayerType> = [];
	var port:Int;
	final userList:UserList;

	public final clients:Array<Client> = [];

	final freeIds:Array<Int> = [];
	final wsEventParser = new JsonParser<WsEvent>();
	final consoleInput:ConsoleInput;
	final cache:Cache;
	final cacheDir:String;
	final videoList = new VideoList();
	final videoTimer = new VideoTimer();
	final messages:Array<Message> = [];
	final flashbacks:Array<FlashbackItem> = [];
	final logger:Logger;
	/**
		Stop video timer after `EMPTY_ROOM_CALLBACK_DELAY` in case
		if server loses connection to all clients for a moment.

		This allows seamless reconnection without rewinds
		to stopped server time.
	**/
	var emptyRoomCallbackTimer:Null<Timer>;
	var isServerPause = false;

	static function main():Void {
		new Main({
			loadState: true
		});
	}

	function new(opts:MainOptions) {
		isNoState = !opts.loadState;
		final args = Utils.parseArgs(Sys.args(), false);
		verbose = args.exists("verbose");
		userDir = '$rootDir/user';
		statePath = '$userDir/state.json';
		logsDir = '$userDir/logs';
		cacheDir = '$userDir/res/cache';

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
		cache = new Cache(this, cacheDir);
		if (cache.isYtReady) playersCacheSupport.push(YoutubeType);
		initIntergationHandlers();
		loadState();
		config = loadUserConfig();
		cache.setStorageLimit(cast config.cacheStorageLimitGiB * 1024 * 1024 * 1024);
		userList = loadUsers();
		config.isVerbose = verbose;
		config.salt = generateConfigSalt();
		if (config.localNetworkOnly) localIp = "127.0.0.1";
		else localIp = Utils.getLocalIp();
		globalIp = localIp;
		port = config.port;
		final envPort = (process.env : Dynamic).PORT;
		if (envPort != null) port = envPort;
		final argPort = args["port"];
		if (argPort != null) {
			final newPort = Std.parseInt(argPort);
			if (newPort != null) port = newPort;
		}

		var attempts = isNoState ? 500 : 5;
		function preparePort():Void {
			Utils.isPortFree(port, isFree -> {
				if (!isFree && attempts > 0) {
					trace('Warning: port $port is already in use. Changed to ${port + 1}');
					attempts--;
					port++;
					preparePort();
					return;
				}
				runServer();
			});
		}
		preparePort();
	}

	function runServer():Void {
		trace('Local: http://$localIp:$port');
		if (config.localNetworkOnly) {
			trace("Global network is disabled in config");
		} else {
			if (!isNoState) Utils.getGlobalIp(ip -> {
				final isIp6 = ip.contains(":");
				if (isIp6) ip = '[$ip]';
				globalIp = ip;
				trace('Global: http://$globalIp:$port');
			});
		}

		final dir = '$rootDir/res';
		final httpServer = new HttpServer(this, {
			dir: dir,
			customDir: '$userDir/res',
			allowLocalRequests: config.localAdmins,
			cache: cache,
		});
		Lang.init('$dir/langs');

		final server = Http.createServer((req, res) -> {
			httpServer.serveFiles(req, res);
		});
		wss = new WSServer({server: server});
		wss.on("connection", onConnect);
		if (config.localNetworkOnly) server.listen(port, localIp, onServerInited);
		else server.listen(port, onServerInited);

		new Timer(25000).run = () -> {
			for (client in clients) {
				if (client.isAlive) {
					client.isAlive = false;
					client.ws.ping();
					continue;
				}
				client.ws.terminate();
			}
		};
	}

	dynamic function onServerInited():Void {};

	public function exit():Void {
		saveState();
		logger.saveLog();
		process.exit();
	}

	function generateConfigSalt():String {
		userList.salt ??= Sha256.encode('${Math.random()}');
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
				for (item in getPermissions(type)) {
					group.push(item);
				}
			}
		}
		return config;
	}

	function getUserConfig():Config {
		final config:Config = Json.parse(File.getContent('$rootDir/default-config.json'));
		if (isNoState) return config;
		final customPath = '$userDir/config.json';
		if (!FileSystem.exists(customPath)) return config;
		final customConfig:Config = Json.parse(File.getContent(customPath));
		for (field in Reflect.fields(customConfig)) {
			if (Reflect.field(config, field) == null) {
				trace('Warning: config field "$field" is unknown');
			}
			Reflect.setField(config, field, Reflect.field(customConfig, field));
		}
		final emoteCopies:Map<String, Bool> = [];
		for (emote in config.emotes) {
			if (emoteCopies[emote.name]) trace('Warning: emote name "${emote.name}" has copy');
			emoteCopies[emote.name] = true;
			if (!verbose) continue;
			if (emoteCopies[emote.image]) {
				trace('Warning: emote url of name "${emote.name}" has copy');
			}
			emoteCopies[emote.image] = true;
		}
		return config;
	}

	function loadUsers():UserList {
		final customPath = '$userDir/users.json';
		if (isNoState || !FileSystem.exists(customPath)) return {
			admins: [],
			bans: []
		};
		final users:UserList = Json.parse(File.getContent(customPath));
		users.admins ??= [];
		users.bans ??= [];
		for (field in users.bans) {
			field.toDate = Date.fromString(cast field.toDate);
		}
		return users;
	}

	function writeUsers(users:UserList):Void {
		Utils.ensureDir(userDir);
		final data:UserList = {
			admins: users.admins,
			bans: [
				for (field in users.bans) {
					ip: field.ip,
					toDate: cast field.toDate.toString()
				}
			],
			salt: users.salt
		}
		File.saveContent('$userDir/users.json', Json.stringify(data, "\t"));
	}

	function saveState():Void {
		trace("Saving state...");
		final json = Json.stringify(getCurrentState(), "\t");
		File.saveContent(statePath, json);
		writeUsers(userList);
	}

	function getCurrentState():ServerState {
		return {
			videoList: videoList.getItems(),
			isPlaylistOpen: videoList.isOpen,
			itemPos: videoList.pos,
			messages: messages,
			timer: {
				time: videoTimer.getTime(),
				paused: videoTimer.isPaused()
			},
			flashbacks: flashbacks,
			cachedFiles: cache.getCachedFiles()
		}
	}

	function loadState():Void {
		if (isNoState) return;
		if (!FileSystem.exists(statePath)) return;
		trace("Loading state...");
		final state:ServerState = Json.parse(File.getContent(statePath));
		state.flashbacks ??= [];
		state.cachedFiles ??= [];

		videoList.setItems(state.videoList);
		videoList.isOpen = state.isPlaylistOpen;
		videoList.setPos(state.itemPos);

		messages.resize(0);
		for (message in state.messages) messages.push(message);

		flashbacks.resize(0);
		for (flashback in state.flashbacks) flashbacks.push(flashback);

		cache.setCachedFiles(state.cachedFiles);

		videoTimer.start();
		videoTimer.setTime(state.timer.time);
		videoTimer.pause();
	}

	function logError(type:String, data:Dynamic):Void {
		cache.removeOlderCache(1024 * 1024);
		trace(type, data);
		final crashesFolder = '$userDir/crashes';
		Utils.ensureDir(crashesFolder);
		final name = DateTools.format(Date.now(), "%Y-%m-%d_%H_%M_%S") + "-" + type;
		File.saveContent('$crashesFolder/$name.json', Json.stringify(data, "\t"));
	}

	var isHeroku = false;

	function initIntergationHandlers():Void {
		isHeroku = process.env["_"] != null && process.env["_"].contains("heroku");
		// Prevent heroku idle when clients online (needs APP_URL env var)
		if (isHeroku && process.env["APP_URL"] != null) {
			var url = process.env["APP_URL"];
			if (!url.startsWith("http")) url = 'http://$url';
			new Timer(10 * 60 * 1000).run = () -> {
				if (clients.length == 0) return;
				trace('Ping $url');
				Http.get(url, r -> {});
			}
		}
	}

	function clientIp(req:IncomingMessage):String {
		// Heroku uses internal proxy, so header cannot be spoofed
		if (config.allowProxyIps || isHeroku) {
			final forwarded:String = req.headers["x-forwarded-for"];
			if (forwarded == null || forwarded.length == 0) return req.socket.remoteAddress;
			return forwarded.split(",")[0].trim();
		}
		return req.socket.remoteAddress;
	}

	public function addAdmin(name:String, password:String):Void {
		password += config.salt;
		final hash = Sha256.encode(password);
		userList.admins.push({
			name: name,
			hash: hash
		});
		trace('Admin $name added.');
	}

	public function removeAdmin(name:String):Void {
		userList.admins.remove(
			userList.admins.find(item -> item.name == name)
		);
		trace('Admin $name removed.');
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

	function randomUuid():String {
		return (Crypto : Dynamic).randomUUID();
	}

	function getUrlUuid(link:String):Null<String> {
		try {
			if (link.startsWith('/')) link = 'http://127.0.0.1$link';
			final url = new URL(link);
			return url.searchParams.get("uuid");
		} catch (e) {
			return null;
		}
	}

	function onConnect(ws:WebSocket, req:IncomingMessage):Void {
		final uuid = getUrlUuid(req.url) ?? randomUuid();
		final oldClient = clients.find(client -> client.uuid == uuid);
		if (oldClient != null) {
			send(oldClient, {type: KickClient});
			onMessage(oldClient, {type: Disconnected}, true);
		}

		final ip = clientIp(req);
		final id = freeIds.length > 0 ? freeIds.shift() : clients.length;
		final name = 'Guest ${id + 1}';
		trace(Date.now().toString(), '$name connected ($ip)');
		final isAdmin = config.localAdmins && req.socket.localAddress == ip;
		final client = new Client(ws, req, id, name, 0);
		client.uuid = uuid;
		client.isAdmin = isAdmin;
		clients.push(client);
		ws.on("pong", () -> client.isAlive = true);
		onMessage(client, {
			type: Connected
		}, true);

		ws.on("message", (data:js.node.Buffer) -> {
			final obj = wsEventParser.fromJson(data.toString());
			if (wsEventParser.errors.length > 0 || noTypeObj(obj)) {
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

	function noTypeObj(data:WsEvent):Bool {
		if (data.type == GetTime) return false;
		if (data.type == Flashback) return false;
		if (data.type == TogglePlaylistLock) return false;
		if (data.type == UpdatePlaylist) return false;
		if (data.type == Logout) return false;
		if (data.type == Dump) return false;
		// check if request has same field as type value
		final t:String = cast data.type;
		final t = t.charAt(0).toLowerCase() + t.substr(1);
		return js.Syntax.strictEq(Reflect.field(data, t), null);
	}

	function onMessage(client:Client, data:WsEvent, internal:Bool):Void {
		logger.log({
			clientName: client.name,
			clientGroup: client.group.toInt(),
			event: data,
			time: Date.now().toString()
		});
		switch (data.type) {
			case Connected:
				if (!internal) return;
				emptyRoomCallbackTimer?.stop();
				if (clients.length == 1 && videoList.length > 0) {
					if (!isServerPause) {
						if (videoTimer.isPaused()) videoTimer.play();
					}
				}

				checkBan(client);
				send(client, {
					type: Connected,
					connected: {
						uuid: client.uuid,
						config: config,
						history: messages,
						isUnknownClient: true,
						clientName: client.name,
						clients: clientList(),
						videoList: videoList.getItems(),
						isPlaylistOpen: videoList.isOpen,
						itemPos: videoList.pos,
						globalIp: globalIp,
						playersCacheSupport: playersCacheSupport,
					}
				});
				sendClientListExcept(client);

			case Disconnected:
				if (!internal) return;
				trace(Date.now().toString(), 'Client ${client.name} disconnected');
				Utils.sortedPush(freeIds, client.id);
				clients.remove(client);
				sendClientList();
				if (client.isLeader) {
					if (videoList.length > 0) {
						videoTimer.pause();
						isServerPause = true;
					}
				}
				if (clients.length == 0) {
					emptyRoomCallbackTimer?.stop();
					emptyRoomCallbackTimer = Timer.delay(() -> {
						if (clients.length > 0) return;
						waitVideoStart?.stop();
						videoTimer.pause();
					}, EMPTY_ROOM_CALLBACK_DELAY);
				}
				Timer.delay(() -> {
					if (clients.exists(i -> i.name == client.name)) return;
					broadcast({
						type: ServerMessage,
						serverMessage: {
							textId: '${client.name} has left'
						}
					});
				}, 5000);

			case UpdateClients:
				sendClientList();

			case BanClient:
				if (!checkPermission(client, BanClientPerm)) return;
				final name = data.banClient.name;
				final bannedClient = clients.getByName(name) ?? return;
				if (client.name == name || bannedClient.isAdmin) {
					serverMessage(client, "adminsCannotBeBannedError");
					return;
				}
				final ip = clientIp(bannedClient.req);
				userList.bans.remove(userList.bans.find(item -> item.ip == ip));
				if (data.banClient.time == 0) {
					bannedClient.isBanned = false;
					sendClientList();
					return;
				}
				final currentTime = Date.now().getTime();
				final time = currentTime + data.banClient.time * 1000;
				if (time < currentTime) return;
				userList.bans.push({
					ip: ip,
					toDate: Date.fromTime(time)
				});
				checkBan(bannedClient);
				serverMessage(client, '${bannedClient.name} ($ip) has been banned.');
				sendClientList();

			case KickClient:
				if (!checkPermission(client, BanClientPerm)) return;
				final name = data.kickClient.name;
				final kickedClient = clients.getByName(name) ?? return;
				if (client.name != name && kickedClient.isAdmin) {
					serverMessage(client, "adminsCannotBeBannedError");
					return;
				}
				send(kickedClient, {type: KickClient});

			case Login:
				final name = data.login.clientName.trim();
				final lcName = name.toLowerCase();
				if (badNickName(lcName)) {
					serverMessage(client, "usernameError");
					send(client, {type: LoginError});
					return;
				}
				final hash = data.login.passHash;
				if (hash == null) {
					if (userList.admins.exists(a -> a.name.toLowerCase() == lcName)) {
						send(client, {type: PasswordRequest});
						return;
					}
				} else {
					if (userList.admins.exists(
						a -> a.name.toLowerCase() == lcName && a.hash == hash)) {
						client.isAdmin = true;
					} else {
						serverMessage(client, "passwordMatchError");
						send(client, {type: LoginError});
						return;
					}
				}
				trace(Date.now().toString(), 'Client ${client.name} logged as $name');
				client.name = name;
				client.isUser = true;
				checkBan(client);
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
				trace(Date.now().toString(), 'Client $oldName logout to ${client.name}');
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
				final date = Date.now();
				final utcTime = date.getTime() + date.getTimezoneOffset() * 60 * 1000;
				final time = Date.fromTime(utcTime).toString();
				messages.push({text: text, name: client.name, time: time});
				if (messages.length > config.serverChatHistory) messages.shift();
				broadcast(data);

			case ServerMessage:
			case Progress:
			case AddVideo:
				if (isPlaylistLockedFor(client)) return;
				if (!checkPermission(client, AddVideoPerm)) return;
				if (config.totalVideoLimit != 0 && videoList.length >= config.totalVideoLimit) {
					serverMessage(client, "totalVideoLimitError");
					return;
				}
				if (config.userVideoLimit != 0 && !client.isAdmin
					&& videoList.itemsByUser(client) >= config.userVideoLimit) {
					serverMessage(client, "videoLimitPerUserError");
					return;
				}
				if (!data.addVideo.atEnd && !checkPermission(client, ChangeOrderPerm)) {
					data.addVideo.atEnd = true;
				}
				var item = data.addVideo.item;
				item.author = client.name;
				final localIpPort = '$localIp:$port';
				if (item.url.contains(localIpPort)) {
					final newUrl = item.url.replace(localIpPort, '$globalIp:$port');
					item = item.withUrl(newUrl);
				}
				if (videoList.exists(i -> i.url == item.url)) {
					serverMessage(client, "videoAlreadyExistsError");
					return;
				}

				inline function addVideo():Void {
					data.addVideo.item = item;
					videoList.addItem(item, data.addVideo.atEnd);
					broadcast(data);
					// Initial timer start if VideoLoaded is not happen
					if (videoList.length == 1) restartWaitTimer();
				}
				if (!item.doCache) {
					addVideo();
				} else {
					switch item.playerType {
						case YoutubeType:
							cache.cacheYoutubeVideo(client, item.url, (name) -> {
								item = item.withUrl(cache.getFileUrl(name));
								if (item.duration > 1) item.duration -= 1;
								addVideo();
							});
						case type:
							final name = '$type'.replace("Type", "");
							serverMessage(client, 'No cache support for $name player.');
							addVideo();
					}
				}

			case VideoLoaded:
				// Called if client loads next video and can play it
				if (isServerPause) return;
				prepareVideoPlayback();

			case RemoveVideo:
				if (isPlaylistLockedFor(client)) return;
				if (!checkPermission(client, RemoveVideoPerm)) return;
				if (videoList.length == 0) return;
				final url = data.removeVideo.url;
				final index = videoList.findIndex(item -> item.url == url);
				if (index == -1) return;

				final isCurrent = videoList.currentItem.url == url;
				if (isCurrent && videoTimer.getTime() > FLASHBACK_DIST) {
					saveFlashbackTime(videoList.currentItem);
				}
				videoList.removeItem(index);
				broadcast(data);
				if (isCurrent && videoList.length > 0) restartWaitTimer();

			case SkipVideo:
				if (!checkPermission(client, RemoveVideoPerm)) return;
				skipVideo(data);

			case Pause:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				if (Math.abs(data.pause.time - videoTimer.getTime()) > FLASHBACK_DIST) {
					saveFlashbackTime(videoList.currentItem);
				}
				videoTimer.setTime(data.pause.time);
				videoTimer.pause();
				broadcast({
					type: data.type,
					pause: data.pause
				});

			case Play:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				if (Math.abs(data.play.time - videoTimer.getTime()) > FLASHBACK_DIST) {
					saveFlashbackTime(videoList.currentItem);
				}
				videoTimer.setTime(data.play.time);
				isServerPause = false;
				videoTimer.play();
				broadcast({
					type: data.type,
					play: data.play
				});

			case GetTime:
				if (videoList.length == 0) return;
				final maxTime = videoList.currentItem.duration - 0.01;
				if (videoTimer.getTime() > maxTime) {
					videoTimer.pause();
					videoTimer.setTime(maxTime);
					final skipUrl = videoList.currentItem.url;
					Timer.delay(() -> {
						skipVideo({
							type: SkipVideo,
							skipVideo: {
								url: skipUrl
							}
						});
					}, VIDEO_SKIP_DELAY);
					return;
				}
				final obj:WsEvent = {
					type: GetTime,
					getTime: {
						time: videoTimer.getTime()
					}
				};
				if (videoTimer.isPaused()) obj.getTime.paused = true;
				if (isServerPause) obj.getTime.pausedByServer = true;
				if (videoTimer.getRate() != 1) {
					if (!clients.hasLeader()) videoTimer.setRate(1);
					else obj.getTime.rate = videoTimer.getRate();
				}
				send(client, obj);

			case SetTime:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				if (Math.abs(data.setTime.time - videoTimer.getTime()) > FLASHBACK_DIST) {
					saveFlashbackTime(videoList.currentItem);
				}
				videoTimer.setTime(data.setTime.time);
				broadcastExcept(client, {
					type: data.type,
					setTime: data.setTime
				});

			case SetRate:
				if (videoList.length == 0) return;
				if (!client.isLeader) return;
				videoTimer.setRate(data.setRate.rate);
				broadcastExcept(client, {
					type: data.type,
					setRate: data.setRate
				});

			case Rewind:
				if (!checkPermission(client, RewindPerm)) return;
				if (videoList.length == 0) return;
				data.rewind.time += videoTimer.getTime();
				if (data.rewind.time < 0) data.rewind.time = 0;
				saveFlashbackTime(videoList.currentItem);
				videoTimer.setTime(data.rewind.time);
				broadcast({
					type: data.type,
					rewind: data.rewind
				});

			case Flashback:
				if (!checkPermission(client, RewindPerm)) return;
				if (videoList.length == 0) return;
				loadFlashbackTime(videoList.currentItem);
				broadcast({
					type: Rewind,
					rewind: {
						time: videoTimer.getTime()
					}
				});

			case SetLeader:
				final clientName = data.setLeader.clientName;
				if (client.name == clientName) {
					if (!checkPermission(client, RequestLeaderPerm)) return;
				} else if (!client.isLeader && clientName != "") {
					if (!checkPermission(client, SetLeaderPerm)) return;
				}
				isServerPause = false;
				clients.setLeader(clientName);
				broadcast({
					type: SetLeader,
					setLeader: {
						clientName: clientName
					}
				});
				if (videoList.length == 0) return;
				if (!clients.hasLeader()) {
					if (videoTimer.isPaused()) videoTimer.play();
					videoTimer.setRate(1);
					broadcast({
						type: Play,
						play: {
							time: videoTimer.getTime()
						}
					});
				}

			case PlayItem:
				if (!checkPermission(client, ChangeOrderPerm)) return;
				final pos = data.playItem.pos;
				if (!videoList.hasItem(pos)) return;
				if (videoTimer.getTime() > FLASHBACK_DIST) {
					saveFlashbackTime(videoList.currentItem);
				}
				videoList.setPos(pos);
				data.playItem.pos = videoList.pos;
				restartWaitTimer();
				broadcast(data);

			case SetNextItem:
				if (isPlaylistLockedFor(client)) return;
				if (!checkPermission(client, ChangeOrderPerm)) return;
				final pos = data.setNextItem.pos;
				if (!videoList.hasItem(pos)) return;
				if (pos == videoList.pos || pos == videoList.pos + 1) return;
				videoList.setNextItem(pos);
				broadcast(data);

			case ToggleItemType:
				if (isPlaylistLockedFor(client)) return;
				if (!checkPermission(client, ToggleItemTypePerm)) return;
				final pos = data.toggleItemType.pos;
				if (!videoList.hasItem(pos)) return;
				videoList.toggleItemType(pos);
				broadcast(data);

			case ClearChat:
				if (!checkPermission(client, ClearChatPerm)) return;
				messages.resize(0);
				broadcast(data);

			case ClearPlaylist:
				if (isPlaylistLockedFor(client)) return;
				if (!checkPermission(client, RemoveVideoPerm)) return;
				if (videoTimer.getTime() > FLASHBACK_DIST) {
					saveFlashbackTime(videoList.currentItem);
				}
				videoTimer.stop();
				videoList.clear();
				broadcast(data);

			case ShufflePlaylist:
				if (isPlaylistLockedFor(client)) return;
				if (!checkPermission(client, ChangeOrderPerm)) return;
				if (videoList.length == 0) return;
				videoList.shuffle();
				broadcast({
					type: UpdatePlaylist,
					updatePlaylist: {
						videoList: videoList.getItems()
					}
				});

			case UpdatePlaylist:
				broadcast({
					type: UpdatePlaylist,
					updatePlaylist: {
						videoList: videoList.getItems()
					}
				});

			case TogglePlaylistLock:
				if (!checkPermission(client, LockPlaylistPerm)) return;
				videoList.isOpen = !videoList.isOpen;
				broadcast({
					type: TogglePlaylistLock,
					togglePlaylistLock: {
						isOpen: videoList.isOpen
					}
				});

			case Dump:
				if (!client.isAdmin) return;
				final data = {
					state: getCurrentState(),
					clients: clients.map(client -> {
						name: client.name,
						id: client.id,
						ip: clientIp(client.req),
						isBanned: client.isBanned,
						isAdmin: client.isAdmin,
						isLeader: client.isLeader,
						isUser: client.isUser,
					}),
					logs: logger.getLogs()
				}
				final json = jsonStringify(data, "\t");
				serverMessage(client, "Free space: "
					+ (cache.getFreeSpace() / 1024).toFixed()
					+ "KiB");
				send(client, {
					type: Dump,
					dump: {
						data: json
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

	public function serverMessage(client:Client, textId:String):Void {
		send(client, {
			type: ServerMessage,
			serverMessage: {
				textId: textId
			}
		});
	}

	public function send(client:Client, data:WsEvent):Void {
		client.ws.send(jsonStringify(data), null);
	}

	public function broadcast(data:WsEvent):Void {
		final json = jsonStringify(data);
		for (client in clients)
			client.ws.send(json, null);
	}

	public function broadcastExcept(skipped:Client, data:WsEvent):Void {
		final json = jsonStringify(data);
		for (client in clients) {
			if (client == skipped) continue;
			client.ws.send(json, null);
		}
	}

	public static function jsonStringify(data:Any, ?space:String):String {
		return Json.stringify(data, jsonFilterNulls, space);
	}

	static function jsonFilterNulls(key:Any, value:Any):Any {
		#if js
		if (value == null) return js.Lib.undefined;
		#end
		return value;
	}

	function skipVideo(data:WsEvent):Void {
		if (videoList.length == 0) return;
		final item = videoList.currentItem;
		if (item.url != data.skipVideo.url) return;
		final dur = videoList.currentItem.duration;
		if (videoTimer.getTime() > FLASHBACK_DIST
			&& videoTimer.getTime() < dur - FLASHBACK_DIST) {
			saveFlashbackTime(videoList.currentItem);
		}
		videoList.skipItem();
		if (videoList.length > 0) restartWaitTimer();
		broadcast(data);
	}

	function checkPermission(client:Client, perm:Permission):Bool {
		if (client.isBanned) checkBan(client);
		final state = client.hasPermission(perm, config.permissions);
		if (!state) {
			serverMessage(client, 'accessError|$perm');
		}
		return state;
	}

	function checkBan(client:Client):Void {
		if (client.isAdmin) {
			client.isBanned = false;
			return;
		}
		final ip = clientIp(client.req);
		final currentTime = Date.now().getTime();
		for (ban in userList.bans.reversed()) {
			if (ban.ip != ip) continue;
			final isOutdated = ban.toDate.getTime() < currentTime;
			client.isBanned = !isOutdated;
			if (isOutdated) {
				userList.bans.remove(ban);
				trace('${client.name} ban removed');
				sendClientList();
			}
			break;
		}
	}

	final matchHtmlChars = ~/[&^<>'"]/;
	final matchGuestName = ~/guest [0-9]+/;

	public function badNickName(name:String):Bool {
		if (name.length > config.maxLoginLength) return true;
		if (name.length == 0) return true;
		if (matchHtmlChars.match(name)) return true;
		if (matchGuestName.match(name)) return true;
		if (clients.exists(i -> i.name.toLowerCase() == name)) return true;
		return false;
	}

	var waitVideoStart:Null<Timer>;
	var loadedClientsCount = 0;

	function restartWaitTimer():Void {
		videoTimer.stop();
		waitVideoStart?.stop();
		waitVideoStart = Timer.delay(startVideoPlayback, VIDEO_START_MAX_DELAY);
	}

	function prepareVideoPlayback():Void {
		if (videoTimer.isStarted) return;
		loadedClientsCount++;
		if (loadedClientsCount == 1) restartWaitTimer();
		if (loadedClientsCount >= clients.length) startVideoPlayback();
	}

	function startVideoPlayback():Void {
		waitVideoStart?.stop();
		loadedClientsCount = 0;
		broadcast({type: VideoLoaded});
		isServerPause = false;
		videoTimer.start();
	}

	function saveFlashbackTime(item:VideoItem):Void {
		final url = item.url;
		final duration = item.duration;
		final time = videoTimer.getTime();
		final flashbackTime = findFlashbackTime(url, duration);
		if (Math.abs(flashbackTime - time) < FLASHBACK_DIST) return;
		addRecentFlashback(url, duration, time);
	}

	function loadFlashbackTime(item:VideoItem):Void {
		final url = item.url;
		final duration = item.duration;
		final time = videoTimer.getTime();
		final flashbackTime = findFlashbackTime(url, duration);
		videoTimer.setTime(flashbackTime);
		addRecentFlashback(url, duration, time);
	}

	function findFlashbackTime(url:String, duration:Float):Float {
		return findFlashbackItem(url, duration)?.time ?? 0.0;
	}

	function findFlashbackItem(url:String, ?duration:Float):Null<FlashbackItem> {
		var item = flashbacks.find(item -> item.url == url);
		// if there is no url match, find recent flashback item with same duration
		if (duration != null && item == null) {
			item = flashbacks.find(item -> item.duration == duration);
		}
		return item;
	}

	function addRecentFlashback(url:String, duration:Float, time:Float):Void {
		flashbacks.remove(findFlashbackItem(url));
		flashbacks.unshift({
			url: url,
			duration: duration,
			time: time
		});
		while (flashbacks.length > FLASHBACKS_COUNT) {
			flashbacks.pop();
		}
	}

	function isPlaylistLockedFor(client:Client):Bool {
		if (!videoList.isOpen) {
			if (!checkPermission(client, LockPlaylistPerm)) return true;
		}
		return false;
	}
}
