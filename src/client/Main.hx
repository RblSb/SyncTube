package client;

import Client.ClientData;
import Types.Config;
import Types.GetTimeEvent;
import Types.Permission;
import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.WsEvent;
import haxe.Json;
import haxe.Timer;
import haxe.crypto.Sha256;
import js.Browser.document;
import js.Browser.window;
import js.Browser;
import js.html.ButtonElement;
import js.html.Element;
import js.html.Event;
import js.html.InputElement;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.TransitionEvent;
import js.html.URL;
import js.html.VideoElement;
import js.html.WebSocket;

class Main {
	public static var instance(default, null):Main;
	static inline var SETTINGS_VERSION = 5;

	public final settings:ClientSettings;
	public var isSyncActive = true;
	public var forceSyncNextTick = false;
	public var isVideoEnabled(default, null) = true;
	public final host:String;
	public var globalIp(default, null) = "";
	public var isPlaylistOpen(default, null) = true;
	public var playersCacheSupport(default, null):Array<PlayerType> = [];
	public var showingServerPause(default, null) = false;
	/** How much time passed since lastState.time update **/
	public var timeFromLastState(default, null) = 0.0;
	public final lastState:GetTimeEvent = {
		time: 0,
		rate: 1.0,
		paused: false,
		pausedByServer: false
	};

	var lastStateTimeStamp = 0.0;

	final clients:Array<Client> = [];
	var pageTitle = document.title;
	var config:Null<Config>;
	final filters:Array<{regex:EReg, replace:String}> = [];
	var personal = new Client("Unknown", 0);
	var isConnected = false;
	var gotInitialConnection = false;
	var disabledReconnection = false;
	var disconnectNotification:Null<Timer>;
	var ws:WebSocket;
	final player:Player;
	var onTimeGet:Timer;
	var onBlinkTab:Null<Timer>;
	var gotFirstPageInteraction = false;
	var msgBuf = getEl("#messagebuffer");

	static function main():Void {
		instance = new Main();
	}

	function new() {
		haxe.Log.trace = Utils.nativeTrace;
		player = new Player(this);
		host = Browser.location.hostname;
		if (host == "") host = "localhost";

		final defaults:ClientSettings = {
			version: SETTINGS_VERSION,
			uuid: null,
			name: "",
			hash: "",
			isExtendedPlayer: false,
			playerSize: 1,
			chatSize: 300,
			synchThreshold: 2,
			isSwapped: false,
			isUserListHidden: true,
			latestLinks: [],
			latestSubs: [],
			hotkeysEnabled: true,
			showHintList: true,
			checkboxes: [],
		}
		Settings.init(defaults, settingsPatcher);
		settings = Settings.read();

		initListeners();
		onTimeGet = new Timer(settings.synchThreshold * 1000);
		onTimeGet.run = requestTime;
		document.onvisibilitychange = () -> {
			if (!document.hidden && onBlinkTab != null) {
				document.title = getPageTitle();
				onBlinkTab.stop();
				onBlinkTab = null;
			}
		}
		Lang.init("langs", () -> {
			Buttons.initTextButtons(this);
			Buttons.initHotkeys(this, player);
			openWebSocket();
		});
		JsApi.init(this, player);

		document.addEventListener("click", onFirstInteraction);
	}

	function onFirstInteraction():Void {
		if (gotFirstPageInteraction) return;
		if (!player.isVideoLoaded()) return;
		gotFirstPageInteraction = true;
		player.unmute();
		if (!hasLeader() && !showingServerPause) player.play();
		document.removeEventListener("click", onFirstInteraction);
	}

	function settingsPatcher(data:Any, version:Int):Any {
		switch (version) {
			case 1:
				final data:ClientSettings = data;
				data.hotkeysEnabled = true;
			case 2:
				final data:ClientSettings = data;
				data.latestSubs = [];
			case 3:
				final data:ClientSettings = data;
				data.showHintList = true;
			case 4:
				final data:ClientSettings = data;
				data.checkboxes = [];
			case SETTINGS_VERSION, _:
				throw 'skipped version $version';
		}
		return data;
	}

	function requestTime():Void {
		if (!isSyncActive) return;
		if (player.isListEmpty()) return;
		send({type: GetTime});
	}

	function openWebSocket():Void {
		var protocol = "ws:";
		if (Browser.location.protocol == "https:") protocol = "wss:";
		final port = Browser.location.port;
		final colonPort = port.length > 0 ? ':$port' : port;
		final path = Browser.location.pathname;
		final query = settings.uuid == null ? "" : '?uuid=${settings.uuid}';
		ws = new WebSocket('$protocol//$host$colonPort$path$query');
		ws.onmessage = onMessage;
		ws.onopen = () -> {
			disconnectNotification?.stop();
			disconnectNotification = null;
			chatMessageConnected();
			gotInitialConnection = true;
			isConnected = true;
		}
		// if initial connection refused, or server/client is offline
		ws.onclose = () -> {
			isConnected = false;
			var notificationDelay = gotInitialConnection ? 5000 : 0;
			if (disabledReconnection) notificationDelay = 0;

			if (disconnectNotification == null) {
				disconnectNotification = Timer.delay(() -> {
					if (isConnected) return;
					chatMessageDisconnected();
					player.pause();
				}, notificationDelay);
			}

			if (disabledReconnection) return;
			final reconnectionDelay = gotInitialConnection ? 1000 : 2000;
			Timer.delay(openWebSocket, reconnectionDelay);
		}
	}

	function initListeners():Void {
		Buttons.init(this);

		final leaderBtn = getEl("#leader_btn");
		leaderBtn.onclick = toggleLeader;
		leaderBtn.oncontextmenu = (e:MouseEvent) -> {
			toggleLeaderAndPause();
			e.preventDefault();
		}

		final voteSkip = getEl("#voteskip");
		voteSkip.onclick = e -> {
			if (Utils.isTouch() && !window.confirm(Lang.get("skipItemConfirm"))) return;
			if (player.isListEmpty()) return;
			final items = player.getItems();
			final pos = player.getItemPos();
			send({
				type: SkipVideo,
				skipVideo: {
					url: items[pos].url
				}
			});
		}

		getEl("#queue_next").onclick = e -> addVideoUrl(false);
		getEl("#queue_end").onclick = e -> addVideoUrl(true);
		new InputWithHistory(getEl("#mediaurl"), settings.latestLinks, 10, value -> {
			addVideoUrl(true);
			return false;
		});
		getEl("#mediatitle").onkeydown = (e:KeyboardEvent) -> {
			if (e.keyCode == KeyCode.Return) addVideoUrl(true);
		}
		new InputWithHistory(getEl("#subsurl"), settings.latestSubs, 10, value -> {
			addVideoUrl(true);
			return false;
		});

		getEl("#ce_queue_next").onclick = e -> addIframe(false);
		getEl("#ce_queue_end").onclick = e -> addIframe(true);
		getEl("#customembed-title").onkeydown = (e:KeyboardEvent) -> {
			if (e.keyCode == KeyCode.Return) {
				addIframe(true);
				e.preventDefault();
			}
		}
		getEl("#customembed-content").onkeydown = getEl("#customembed-title").onkeydown;
	}

	public inline function isUser():Bool {
		return personal.isUser;
	}

	public inline function isLeader():Bool {
		return personal.isLeader;
	}

	public inline function isAdmin():Bool {
		return personal.isAdmin;
	}

	public inline function getName():String {
		return personal.name;
	}

	public function hasPermission(permission:Permission):Bool {
		return personal.hasPermission(permission, config.permissions);
	}

	public final urlMask = ~/\${([0-9]+)-([0-9]+)}/g;

	function handleUrlMasks(links:Array<String>):Void {
		for (link in links) {
			if (!urlMask.match(link)) continue;
			final start = Std.parseInt(urlMask.matched(1));
			var end = Std.parseInt(urlMask.matched(2));
			if (Math.abs(start - end) > 100) continue;
			final step = end > start ? -1 : 1;
			final i = links.indexOf(link);
			links.remove(link);
			while (end != start + step) {
				links.insert(i, urlMask.replace(link, '$end'));
				end += step;
			}
		}
	}

	function addVideoUrl(atEnd:Bool):Void {
		final mediaUrl:InputElement = getEl("#mediaurl");
		final subsUrl:InputElement = getEl("#subsurl");
		final checkboxTemp:InputElement = getEl("#addfromurl .add-temp");
		final isTemp = checkboxTemp.checked;
		final checkboxCache:InputElement = getEl("#cache-on-server");
		final doCache = checkboxCache.checked
			&& checkboxCache.parentElement.style.display != "none";
		final url = mediaUrl.value;
		final subs = subsUrl.value;
		if (url.length == 0) return;
		mediaUrl.value = "";
		InputWithHistory.pushIfNotLast(settings.latestLinks, url);
		if (subs.length != 0) {
			InputWithHistory.pushIfNotLast(settings.latestSubs, subs);
		}
		Settings.write(settings);
		final url = ~/, ?(https?)/g.replace(url, "|$1");
		final links = url.split("|");
		handleUrlMasks(links);
		// if videos added as next, we need to load them in reverse order
		if (!atEnd) sortItemsForQueueNext(links);
		addVideoArray(links, atEnd, isTemp, doCache);
	}

	public function getLinkPlayerType(url:String):PlayerType {
		return player.getLinkPlayerType(url);
	}

	public function isSingleVideoUrl(url:String):Bool {
		return player.isSingleVideoUrl(url);
	}

	public function sortItemsForQueueNext<T>(items:Array<T>):Void {
		if (items.length == 0) return;
		// except first item when list empty
		var first:Null<T> = null;
		if (player.isListEmpty()) first = items.shift();
		items.reverse();
		if (first != null) items.unshift(first);
	}

	function addVideoArray(links:Array<String>, atEnd:Bool, isTemp:Bool, doCache:Bool):Void {
		if (links.length == 0) return;
		final link = links.shift();
		addVideo(link, atEnd, isTemp, doCache, () ->
			addVideoArray(links, atEnd, isTemp, doCache));
	}

	public function addVideo(url:String, atEnd:Bool, isTemp:Bool, doCache:Bool, ?callback:() -> Void):Void {
		final protocol = Browser.location.protocol;
		if (url.startsWith("/")) {
			final host = Browser.location.hostname;
			final port = Browser.location.port;
			url = '$protocol//$host:$port$url';
		}
		if (!url.startsWith("http")) url = '$protocol//$url';

		final obj:VideoDataRequest = {
			url: url,
			atEnd: atEnd
		};
		player.getVideoData(obj, (data:VideoData) -> {
			if (data.duration == 0) {
				serverMessage(Lang.get("addVideoError"));
				return;
			}
			data.title ??= Lang.get("rawVideo");
			data.url ??= url;
			send({
				type: AddVideo,
				addVideo: {
					item: {
						url: data.url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp,
						doCache: doCache,
						subs: data.subs,
						voiceOverTrack: data.voiceOverTrack,
						playerType: data.playerType
					},
					atEnd: atEnd
				}
			});
			if (callback != null) callback();
		});
	}

	function addIframe(atEnd:Bool):Void {
		final iframeCode:InputElement = getEl("#customembed-content");
		final iframe = iframeCode.value;
		if (iframe.length == 0) return;
		iframeCode.value = "";
		final mediaTitle:InputElement = getEl("#customembed-title");
		final title = mediaTitle.value;
		mediaTitle.value = "";
		final checkbox:InputElement = getEl("#customembed .add-temp");
		final isTemp = checkbox.checked;
		final obj:VideoDataRequest = {
			url: iframe,
			atEnd: atEnd
		};
		player.getIframeData(obj, (data:VideoData) -> {
			if (data.duration == 0) {
				serverMessage(Lang.get("addVideoError"));
				return;
			}
			if (title.length > 0) data.title = title;
			data.title ??= "Custom Media";
			data.url ??= iframe;
			send({
				type: AddVideo,
				addVideo: {
					item: {
						url: data.url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp,
						doCache: false,
						playerType: IframeType
					},
					atEnd: atEnd
				}
			});
		});
	}

	public function removeVideoItem(url:String) {
		send({
			type: RemoveVideo,
			removeVideo: {
				url: url
			}
		});
	}

	public function toggleVideoElement():Bool {
		isVideoEnabled = !isVideoEnabled;
		if (!isVideoEnabled && player.hasVideo()) {
			player.removeVideo();
		} else if (isVideoEnabled && !player.isListEmpty()) {
			player.setVideo(player.getItemPos());
		}
		return isVideoEnabled;
	}

	public function isListEmpty():Bool {
		return player.isListEmpty();
	}

	public function refreshPlayer():Void {
		player.refresh();
	}

	public function getPlaylistLinks():Array<String> {
		final items = player.getItems();
		return [
			for (item in items) item.url
		];
	}

	public function tryLocalIp(url:String):String {
		if (host == globalIp) return url;
		try {
			final url = new URL(url);
			url.hostname = url.hostname.replace(globalIp, host);
			return '$url';
		} catch (e) {
			return url;
		}
	}

	function onMessage(e):Void {
		final data:WsEvent = Json.parse(e.data);
		if (config != null && config.isVerbose) {
			final t:String = cast data.type;
			final t = t.charAt(0).toLowerCase() + t.substr(1);
			trace('Event: ${data.type}', Reflect.field(data, t));
		}
		JsApi.fireEvents(data);
		switch (data.type) {
			case Connected:
				onConnected(data);
				onTimeGet.run();

			case Disconnected: // server-only
			case Login:
				onLogin(data.login.clients, data.login.clientName);

			case PasswordRequest:
				showGuestPasswordPanel();

			case LoginError:
				settings.name = "";
				settings.hash = "";
				Settings.write(settings);
				showGuestLoginPanel();

			case Logout:
				updateClients(data.logout.clients);
				personal = new Client(data.logout.clientName, 0);
				onUserGroupChanged();
				showGuestLoginPanel();
				settings.name = "";
				settings.hash = "";
				Settings.write(settings);

			case UpdateClients:
				updateClients(data.updateClients.clients);
				final oldGroup = personal.group.toInt();
				personal = clients.getByName(personal.name, personal);
				if (personal.group.toInt() != oldGroup) onUserGroupChanged();

			case BanClient: // server-only
			case KickClient:
				document.title = '*${Lang.get("kicked")}*';
				disabledReconnection = true;
				ws.close();
			case Message:
				addMessage(data.message.clientName, data.message.text);

			case ServerMessage:
				final id = data.serverMessage.textId;
				final text = switch (id) {
					case "usernameError":
						Lang.get(id).replace("$MAX", '${config.maxLoginLength}');
					default:
						Lang.get(id);
				}
				serverMessage(text);

			case Progress:
				final data = data.progress;
				final text = switch data.type {
					case Caching:
						final caching = Lang.get("caching");
						final name = data.data;
						'$caching $name';
					case Downloading: Lang.get("downloading");
					case Uploading: Lang.get("uploading");
				}
				final percent = (data.ratio * 100).toFixed(1);
				var text = '$text...';
				if (percent > 0) text += ' $percent%';
				showProgressInfo(text);
				if (data.ratio == 1) {
					Timer.delay(() -> {
						hideDynamicChin();
					}, 500);
				}

			case AddVideo:
				player.addVideoItem(data.addVideo.item, data.addVideo.atEnd);
				if (player.itemsLength() == 1) player.setVideo(0);

			case VideoLoaded:
				lastState.paused = false;
				lastState.pausedByServer = false;
				lastState.time = 0;
				updateLastStateTime();
				player.setTime(0);
				player.play();
				// try to sync leader after with GetTime events
				if (isLeader() && !player.isVideoLoaded()) forceSyncNextTick = true;

			case RemoveVideo:
				player.removeItem(data.removeVideo.url);
				if (player.isListEmpty()) player.pause();

			case SkipVideo:
				player.skipItem(data.skipVideo.url);
				if (player.isListEmpty()) player.pause();

			case Pause:
				lastState.time = data.pause.time;
				lastState.paused = true;
				updateLastStateTime();
				player.setPauseIndicator(lastState.paused);
				updateUserList();
				if (isLeader()) return;
				player.pause();
				player.setTime(data.pause.time);

			case Play:
				lastState.time = data.play.time;
				lastState.paused = false;
				updateLastStateTime();
				player.setPauseIndicator(lastState.paused);
				updateUserList();
				if (isLeader()) return;
				final synchThreshold = settings.synchThreshold;
				final newTime = data.play.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) >= synchThreshold) {
					player.setTime(newTime);
				}
				player.play();

			case GetTime:
				data.getTime.paused ??= false;
				data.getTime.pausedByServer ??= false;
				data.getTime.rate ??= 1;

				final isPauseChanged = lastState.paused != data.getTime.paused;
				lastState.time = data.getTime.time;
				lastState.paused = data.getTime.paused;
				lastState.pausedByServer = data.getTime.pausedByServer;
				lastState.rate = data.getTime.rate;
				updateLastStateTime();

				if (isPauseChanged) updateUserList();

				final pausedByServer = data.getTime.pausedByServer;
				if (pausedByServer) {
					showServerUnpause();
				} else if (showingServerPause) {
					hideDynamicChin();
				}

				if (player.getPlaybackRate() != data.getTime.rate) {
					player.setPlaybackRate(data.getTime.rate);
				}

				final synchThreshold = settings.synchThreshold;
				final newTime = data.getTime.time;
				final time = player.getTime();
				if (isLeader() && !forceSyncNextTick) {
					// if video is loading on leader
					// move other clients back in time
					if (Math.abs(time - newTime) < synchThreshold) return;
					player.setTime(time, false);
					return;
				}
				if (player.isVideoLoaded()) forceSyncNextTick = false;
				if (player.getDuration() <= player.getTime() + synchThreshold) return;
				if (player.isPaused()) {
					if (!data.getTime.paused) player.play();
				} else {
					if (data.getTime.paused) player.pause();
				}
				player.setPauseIndicator(data.getTime.paused);
				if (Math.abs(time - newTime) < synchThreshold) return;
				// +0.5s for buffering
				if (!data.getTime.paused) player.setTime(newTime + 0.5);
				else player.setTime(newTime);

			case SetTime:
				lastState.time = data.setTime.time;
				updateLastStateTime();
				final synchThreshold = settings.synchThreshold;
				final newTime = data.setTime.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) < synchThreshold) return;
				player.setTime(newTime);

			case SetRate:
				if (isLeader()) return;
				player.setPlaybackRate(data.setRate.rate);

			case Rewind:
				lastState.time = data.rewind.time;
				updateLastStateTime();
				player.setTime(data.rewind.time + 0.5);

			case Flashback: // server-only
			case SetLeader:
				clients.setLeader(data.setLeader.clientName);
				updateUserList();
				setLeaderButton(isLeader());
				if (isLeader()) player.onSetTime();

			case PlayItem:
				player.setVideo(data.playItem.pos);

			case SetNextItem:
				player.setNextItem(data.setNextItem.pos);

			case ToggleItemType:
				player.toggleItemType(data.toggleItemType.pos);

			case ClearChat:
				clearChat();

			case ClearPlaylist:
				player.clearItems();
				if (player.isListEmpty()) player.pause();

			case ShufflePlaylist: // server-only
			case UpdatePlaylist:
				player.setItems(data.updatePlaylist.videoList);

			case TogglePlaylistLock:
				setPlaylistLock(data.togglePlaylistLock.isOpen);

			case Dump:
				Utils.saveFile("dump.json", ApplicationJson, data.dump.data);
		}
	}

	function updateLastStateTime():Void {
		if (lastStateTimeStamp == 0) {
			lastStateTimeStamp = Timer.stamp();
		}
		timeFromLastState = Timer.stamp() - lastStateTimeStamp;
		lastStateTimeStamp = Timer.stamp();
	}

	function onConnected(data:WsEvent):Void {
		final connected = data.connected;

		settings.uuid = connected.uuid;
		Settings.write(settings);

		globalIp = connected.globalIp;
		playersCacheSupport = connected.playersCacheSupport;
		setConfig(connected.config);
		if (connected.isUnknownClient) {
			updateClients(connected.clients);
			personal = clients.getByName(connected.clientName, personal);
			showGuestLoginPanel();
		} else {
			onLogin(connected.clients, connected.clientName);
		}
		final guestName:InputElement = getEl("#guestname");
		var name = settings.name;
		if (name.length == 0) name = guestName.value;
		final hash = settings.hash;
		if (hash.length > 0) loginRequest(name, hash);
		else guestLogin(name);

		setLeaderButton(isLeader());
		setPlaylistLock(connected.isPlaylistOpen);
		clearChat();
		chatMessageConnected();
		for (message in connected.history) {
			addMessage(message.name, message.text, message.time);
		}
		player.setItems(connected.videoList, connected.itemPos);
		onUserGroupChanged();
		if (settings.showHintList) showChatHintList();
	}

	function showChatHintList():Void {
		var text = Lang.get("hintListStart");

		final addVideos = '<button id="addVideosHintButton">${Lang.get("addVideos")}</button>';
		text += "</br>" + Lang.get("hintListAddVideo").replace("$addVideos", addVideos);

		final requestLeader = '<button id="requestLeaderHintButton">${Lang.get("requestLeader")}</button>';
		text += "</br>"
			+ Lang.get("hintListRequestLeader").replace("$requestLeader", requestLeader);

		if (Utils.isTouch()) text += " " + Lang.get("hintListRequestLeaderTouch");
		else text += " " + Lang.get("hintListRequestLeaderMouse");

		if (Utils.isAndroid()) {
			final openInAppLink = '<button id="openInApp">${Lang.get("openInApp")}</button>';
			text += "</br>"
				+ Lang.get("hintListOpenInApp").replace("$openInApp", openInAppLink);
		}

		final hideThisMessage = '<button id="hideHintList">${Lang.get("hideThisMessage")}</button>';
		text += "</br>"
			+ Lang.get("hintListHide").replace("$hideThisMessage", hideThisMessage);

		serverMessage(text, false, false);

		getEl("#addVideosHintButton").onclick = e -> {
			final addBtn = getEl("#showmediaurl");
			addBtn.scrollIntoView();
			Timer.delay(() -> {
				if (!getEl("#addfromurl").classList.contains("collapse")) {
					getEl("#mediaurl").focus();
					return;
				}
				addBtn.onclick();
			}, 300);
		}
		getEl("#requestLeaderHintButton").onclick = (e:MouseEvent) -> {
			window.scrollTo(0, 0);
			if (Utils.isTouch()) blinkLeaderButton();
		}
		getEl("#requestLeaderHintButton").onpointerenter = e -> {
			if (Utils.isTouch()) return;
			getEl("#leader_btn").classList.add("hint");
		}
		getEl("#requestLeaderHintButton").onpointerleave = e -> {
			getEl("#leader_btn").classList.remove("hint");
		}
		if (Utils.isAndroid()) {
			getEl("#openInApp").onclick = e -> {
				var isRedirected = false;
				window.addEventListener("blur", e -> isRedirected = true, {once: true});
				window.setTimeout(function() {
					if (isRedirected || document.hidden) return;
					window.location.href = "https://github.com/RblSb/SyncTubeApp#readme";
				}, 500);
				window.location.href = 'synctube://${Browser.location.href}';
				return false;
			}
		}
		getEl("#hideHintList").onclick = e -> {
			getEl("#hideHintList").parentElement.remove();
			settings.showHintList = false;
			Settings.write(settings);
		}
	}

	public function blinkLeaderButton():Void {
		getEl("#leader_btn").classList.add("hint");
		Timer.delay(() -> getEl("#leader_btn").classList.remove("hint"), 500);
	}

	function onUserGroupChanged():Void {
		final button:ButtonElement = getEl("#queue_next");
		if (personal.hasPermission(ChangeOrderPerm, config.permissions)) {
			button.disabled = false;
		} else {
			button.disabled = true;
		}
		final adminMenu = getEl("#adminMenu");
		if (isAdmin()) adminMenu.style.display = "";
		else adminMenu.style.display = "none";
	}

	public function guestLogin(name:String):Void {
		if (name.length == 0) return;
		send({
			type: Login,
			login: {
				clientName: name
			}
		});
		settings.name = name;
		Settings.write(settings);
	}

	public function userLogin(name:String, password:String):Void {
		if (config.salt == null) return;
		if (password.length == 0) return;
		if (name.length == 0) return;
		final hash = Sha256.encode(password + config.salt);
		loginRequest(name, hash);
		settings.hash = hash;
		Settings.write(settings);
	}

	public function loginRequest(name:String, hash:String):Void {
		send({
			type: Login,
			login: {
				clientName: name,
				passHash: hash
			}
		});
	}

	function setConfig(config:Config):Void {
		this.config = config;
		if (Utils.isTouch()) {
			config.requestLeaderOnPause = false;
			config.unpauseWithoutLeader = false;
		}
		pageTitle = config.channelName;
		final login:InputElement = getEl("#guestname");
		login.maxLength = config.maxLoginLength;
		final form:InputElement = getEl("#chatline");
		form.maxLength = config.maxMessageLength;

		filters.resize(0);
		for (filter in config.filters) {
			filters.push({
				regex: new EReg(filter.regex, filter.flags),
				replace: filter.replace
			});
		}
		for (emote in config.emotes) {
			final isVideoExt = emote.image.endsWith("mp4") || emote.image.endsWith("webm");
			final tag = isVideoExt ? 'video autoplay="" loop="" muted=""' : "img";
			filters.push({
				regex: new EReg("(^| )" + escapeRegExp(emote.name) + "(?!\\S)", "g"),
				replace: '$1<$tag class="channel-emote" src="${emote.image}" title="${emote.name}"/>'
			});
		}
		getEl("#smilesbtn").classList.remove("active");
		final smilesWrap = getEl("#smiles-wrap");
		smilesWrap.style.display = "none";
		final smilesList = getEl("#smiles-list");
		smilesList.onclick = (e:MouseEvent) -> {
			final el:Element = cast e.target;
			if (el == smilesList) return;
			final form:InputElement = getEl("#chatline");
			form.value += ' ${el.title}';
			form.focus();
		}
		smilesList.textContent = "";
		for (emote in config.emotes) {
			final isVideoExt = emote.image.endsWith("mp4") || emote.image.endsWith("webm");
			final tag = isVideoExt ? "video" : "img";
			final el = document.createElement(tag);
			el.className = "smile-preview";
			el.dataset.src = emote.image;
			el.title = emote.name;
			smilesList.appendChild(el);
		}
	}

	function onLogin(data:Array<ClientData>, clientName:String):Void {
		updateClients(data);
		final newPersonal = clients.getByName(clientName) ?? return;
		personal = newPersonal;
		onUserGroupChanged();
		hideGuestLoginPanel();
	}

	function showGuestLoginPanel():Void {
		getEl("#guestlogin").style.display = "";
		getEl("#guestpassword").style.display = "none";
		getEl("#chatbox").style.display = "none";
		getEl("#exitBtn").textContent = Lang.get("login");
	}

	function hideGuestLoginPanel():Void {
		getEl("#guestlogin").style.display = "none";
		getEl("#guestpassword").style.display = "none";
		getEl("#chatbox").style.display = "";
		getEl("#exitBtn").textContent = Lang.get("exit");
	}

	function showGuestPasswordPanel():Void {
		getEl("#guestlogin").style.display = "none";
		getEl("#chatbox").style.display = "none";
		getEl("#guestpassword").style.display = "";
		(getEl("#guestpass") : InputElement).type = "password";
		getEl("#guestpass_icon").setAttribute("name", "eye");
	}

	function updateClients(newClients:Array<ClientData>):Void {
		clients.resize(0);
		for (client in newClients) {
			clients.push(Client.fromData(client));
		}
		updateUserList();
	}

	public function send(data:WsEvent):Void {
		if (!isConnected) return;
		ws.send(Json.stringify(data));
	}

	function chatMessageConnected():Void {
		if (isLastMessageConnectionStatus()) {
			msgBuf.removeChild(msgBuf.lastChild);
		}
		final div = document.createDivElement();
		div.className = "server-msg-reconnect";
		div.textContent = Lang.get("msgConnected");
		addMessageDiv(div);
		scrollChatToEnd();
	}

	function chatMessageDisconnected():Void {
		if (isLastMessageConnectionStatus()) {
			msgBuf.removeChild(msgBuf.lastChild);
		}
		final div = document.createDivElement();
		div.className = "server-msg-disconnect";
		div.textContent = Lang.get("msgDisconnected");
		addMessageDiv(div);
		scrollChatToEnd();
	}

	function isLastMessageConnectionStatus():Bool {
		return msgBuf.lastElementChild?.className.startsWith("server-msg");
	}

	public function serverMessage(text:String, isText = true, withTimestamp = true):Element {
		final div = document.createDivElement();
		final time = Date.now().toString().split(" ")[1];
		div.className = "server-whisper";
		div.innerHTML = '<div class="head">
			<div class="server-whisper"></div>
			<span class="timestamp">${withTimestamp ? time : ""}</span>
		</div>';
		final textDiv = div.querySelector(".server-whisper");
		if (isText) textDiv.textContent = text;
		else textDiv.innerHTML = text;
		addMessageDiv(div);
		scrollChatToEnd();
		return div;
	}

	public function serverHtmlMessage(el:Element):Void {
		final div = document.createDivElement();
		final time = Date.now().toString().split(" ")[1];
		div.className = "server-whisper";
		div.innerHTML = '<div class="head">
			<div class="server-whisper"></div>
			<span class="timestamp">$time</span>
		</div>';
		div.querySelector(".server-whisper").appendChild(el);
		addMessageDiv(div);
		scrollChatToEnd();
	}

	function updateUserList():Void {
		final userCount = getEl("#usercount");
		userCount.textContent = clients.length + " " + Lang.get("online");
		document.title = getPageTitle();

		final list = new StringBuf();
		for (client in clients) {
			list.add('<div class="userlist_item">');
			final iconName = lastState.paused ? "pause" : "play";
			if (client.isLeader) list.add('<ion-icon name="$iconName"></ion-icon>');
			var klass = client.isBanned ? "userlist_banned" : "";
			if (client.isAdmin) klass += " userlist_owner";
			list.add('<span class="$klass">${client.name}</span></div>');
		}
		final userlist = getEl("#userlist");
		userlist.innerHTML = list.toString();
	}

	function getPageTitle():String {
		return '$pageTitle (${clients.length})';
	}

	function clearChat():Void {
		msgBuf.textContent = "";
	}

	function getLocalDateFromUtc(utcDate:String):String {
		final date = Date.fromString(utcDate);
		final localTime = date.getTime() - date.getTimezoneOffset() * 60 * 1000;
		return Date.fromTime(localTime).toString();
	}

	function addMessage(name:String, text:String, ?date:String):Void {
		final userDiv = document.createDivElement();
		userDiv.className = 'chat-msg-$name';

		final headDiv = document.createDivElement();
		headDiv.className = "head";

		final tstamp = document.createSpanElement();
		tstamp.className = "timestamp";
		if (date == null) date = Date.now().toString();
		else date = getLocalDateFromUtc(date);
		final time = date.split(" ")[1];
		tstamp.textContent = time ?? date;
		tstamp.title = date;

		final nameDiv = document.createElement("strong");
		nameDiv.className = "username";
		nameDiv.textContent = name;

		final textDiv = document.createDivElement();
		textDiv.className = "text";
		text = text.htmlEscape();

		for (filter in filters) {
			text = filter.regex.replace(text, filter.replace);
		}
		textDiv.innerHTML = text;
		final inChatEnd = isInChatEnd();

		if (inChatEnd) { // scroll chat to end after images loaded
			for (img in textDiv.getElementsByTagName("img")) {
				img.onload = onChatImageLoaded;
			}
			for (video in textDiv.getElementsByTagName("video")) {
				video.onloadedmetadata = onChatVideoLoaded;
			}
		}

		userDiv.appendChild(headDiv);
		headDiv.appendChild(nameDiv);
		headDiv.appendChild(tstamp);
		userDiv.appendChild(textDiv);
		addMessageDiv(userDiv);

		if (inChatEnd) {
			while (msgBuf.children.length > 200) {
				msgBuf.removeChild(msgBuf.firstChild);
			}
		}
		if (inChatEnd || name == personal.name) {
			scrollChatToEnd();
		} else {
			showScrollToChatEndBtn();
		}
		if (onBlinkTab == null) blinkTabWithTitle('*${Lang.get("chat")}*');
	}

	function addMessageDiv(userDiv:Element):Void {
		if (isMessageBufferReversed()) msgBuf.prepend(userDiv);
		else msgBuf.appendChild(userDiv);
	}

	public function showScrollToChatEndBtn():Void {
		final btn = getEl("#scroll-to-chat-end");
		btn.style.display = "";
		Timer.delay(() -> btn.style.opacity = "1", 0);
	}

	public function hideScrollToChatEndBtn():Void {
		final btn = getEl("#scroll-to-chat-end");
		if (btn.style.opacity == "0") return;
		btn.style.opacity = "0";
		btn.addEventListener("transitionend", e -> {
			btn.style.display = "none";
		}, {once: true});
	}

	public function showProgressInfo(text:String):Void {
		final chin = getEl("#dynamic-chin");
		var div = chin.querySelector("#progress-info");
		if (div == null) {
			div = document.createDivElement();
			div.id = "progress-info";
			chin.prepend(div);
		}
		div.textContent = text;
		showDynamicChin();
	}

	public function showServerUnpause():Void {
		if (showingServerPause) return;
		showingServerPause = true;
		final chin = getEl("#dynamic-chin");
		chin.innerHTML = "";

		final div = document.createDivElement();
		div.className = "server-whisper";
		div.textContent = Lang.get("leaderDisconnectedServerOnPause");
		chin.appendChild(div);
		final btn = document.createButtonElement();
		btn.id = "unpause-server";
		btn.textContent = Lang.get("unpause");
		chin.appendChild(btn);
		btn.onclick = () -> {
			hideDynamicChin();
			send({
				type: SetLeader,
				setLeader: {
					clientName: personal.name
				}
			});
			JsApi.once(SetLeader, event -> removeLeader());
		}

		showDynamicChin();
	}

	function showDynamicChin():Void {
		final chin = getEl("#dynamic-chin");
		if (chin.style.display == "") return;
		chin.style.display = "";
		chin.style.transition = "none";
		chin.classList.remove("collapsed");
		final h = chin.clientHeight;
		chin.classList.add("collapsed");
		Timer.delay(() -> {
			chin.style.transition = "";
			chin.classList.remove("collapsed");
			chin.style.height = '${h}px';
		}, 0);
		function onTransitionEnd(e:TransitionEvent):Void {
			if (e.propertyName != "height") return;
			chin.style.height = "";
			chin.removeEventListener("transitionend", onTransitionEnd);
		}
		chin.addEventListener("transitionend", onTransitionEnd);
	}

	public function hideDynamicChin():Void {
		showingServerPause = false;
		final chin = getEl("#dynamic-chin");
		final h = chin.clientHeight;
		chin.style.height = '${h}px';
		Timer.delay(() -> {
			chin.style.height = "";
			chin.classList.add("collapsed");
		}, 0);
		function onTransitionEnd(e:TransitionEvent):Void {
			if (e.propertyName != "height") return;
			chin.style.display = "none";
			chin.removeEventListener("transitionend", onTransitionEnd);
		}
		chin.addEventListener("transitionend", onTransitionEnd);
	}

	function onChatImageLoaded(e:Event):Void {
		scrollChatToEnd();
		(cast e.target : Element).onload = null;
		final btn = getEl("#scroll-to-chat-end");
		btn.style.opacity = "0";
		btn.style.display = "none";
	}

	var emoteMaxSize:Null<Int>;

	function onChatVideoLoaded(e:Event):Void {
		final el:VideoElement = cast e.target;
		emoteMaxSize ??= Std.parseInt(window.getComputedStyle(el)
			.getPropertyValue("max-width"));
		// fixes default video tag size in chat when tab unloads videos in background
		// (some browsers optimization i guess)
		final max = emoteMaxSize;
		final ratio = Math.min(max / el.videoWidth, max / el.videoHeight);
		el.style.width = '${el.videoWidth * ratio}px';
		el.style.height = '${el.videoHeight * ratio}px';
		scrollChatToEnd();
		el.onloadedmetadata = null;
	}

	public function isMessageBufferReversed():Bool {
		return msgBuf.style.flexDirection == "column-reverse";
	}

	public function isInChatEnd(ignoreOffset = 50):Bool {
		final isReverse = isMessageBufferReversed();
		var scrollTop = msgBuf.scrollTop;
		// zero to negative in column-reverse
		if (isReverse) scrollTop = -scrollTop;
		if (isReverse) return scrollTop <= ignoreOffset;
		return scrollTop + msgBuf.clientHeight >= msgBuf.scrollHeight - ignoreOffset;
	}

	public function scrollChatToEnd():Void {
		final isReverse = isMessageBufferReversed();
		if (isReverse) {
			if (Utils.isMacSafari) msgBuf.scrollTop = -1;
			msgBuf.scrollTop = 0;
		} else {
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
	}

	/* Returns `true` if text should not be sent to chat */
	public function handleCommands(command:String):Bool {
		if (!command.startsWith("/")) return false;
		final args = command.trim().split(" ");
		command = args.shift().substr(1);
		if (command.length == 0) return false;

		switch (command) {
			case "help":
				showChatHintList();
				return true;
			case "ban":
				mergeRedundantArgs(args, 0, 2);
				final name = args[0];
				final time = parseSimpleDate(args[1]);
				if (time < 0) return true;
				send({
					type: BanClient,
					banClient: {
						name: name,
						time: time
					}
				});
				return true;
			case "unban", "removeBan":
				mergeRedundantArgs(args, 0, 1);
				final name = args[0];
				send({
					type: BanClient,
					banClient: {
						name: name,
						time: 0
					}
				});
				return true;
			case "kick":
				mergeRedundantArgs(args, 0, 1);
				final name = args[0];
				send({
					type: KickClient,
					kickClient: {
						name: name
					}
				});
				return true;
			case "clear":
				send({type: ClearChat});
				return true;
			case "flashback", "fb":
				send({type: Flashback});
				return false;
			case "ad":
				player.skipAd();
				return false;
			case "dump":
				send({type: Dump});
				return true;
		}
		if (matchSimpleDate.match(command)) {
			send({
				type: Rewind,
				rewind: {
					time: parseSimpleDate(command)
				}
			});
			return false;
		}
		return false;
	}

	final matchSimpleDate = ~/^-?([0-9]+d)?([0-9]+h)?([0-9]+m)?([0-9]+s?)?$/;

	function parseSimpleDate(text:Null<String>):Int {
		if (text == null) return 0;
		if (!matchSimpleDate.match(text)) return 0;
		final matches:Array<String> = [];
		final length = Utils.matchedNum(matchSimpleDate);
		for (i in 1...length) {
			final group = matchSimpleDate.matched(i);
			if (group == null) continue;
			matches.push(group);
		}
		var seconds = 0;
		for (block in matches) {
			seconds += parseSimpleDateBlock(block);
		}
		if (text.startsWith("-")) seconds = -seconds;
		return seconds;
	}

	function parseSimpleDateBlock(block:String):Int {
		inline function time():Int {
			return Std.parseInt(block.substr(0, block.length - 1));
		}
		if (block.endsWith("s")) return time();
		else if (block.endsWith("m")) return time() * 60;
		else if (block.endsWith("h")) return time() * 60 * 60;
		else if (block.endsWith("d")) return time() * 60 * 60 * 24;
		return Std.parseInt(block);
	}

	function mergeRedundantArgs(args:Array<String>, pos:Int, newLength:Int):Void {
		final count = args.length - (newLength - 1);
		if (count < 2) return;
		args.insert(pos, args.splice(pos, count).join(" "));
	}

	public function blinkTabWithTitle(title:String):Void {
		if (!document.hidden) return;
		if (onBlinkTab != null) onBlinkTab.stop();
		onBlinkTab = new Timer(1000);
		onBlinkTab.run = () -> {
			if (document.title.startsWith(pageTitle)) {
				document.title = title;
			} else {
				document.title = getPageTitle();
			}
		}
		onBlinkTab.run();
	}

	function setLeaderButton(flag:Bool):Void {
		final leaderBtn = getEl("#leader_btn");
		leaderBtn.classList.toggle("success-bg", flag);
	}

	function setPlaylistLock(isOpen:Bool):Void {
		isPlaylistOpen = isOpen;
		final lockPlaylist = getEl("#lockplaylist");
		final icon = lockPlaylist.firstElementChild;
		if (isOpen) {
			lockPlaylist.title = Lang.get("playlistOpen");
			lockPlaylist.classList.add("success");
			lockPlaylist.classList.remove("danger");
			icon.setAttribute("name", "lock-open");
		} else {
			lockPlaylist.title = Lang.get("playlistLocked");
			lockPlaylist.classList.add("danger");
			lockPlaylist.classList.remove("success");
			icon.setAttribute("name", "lock-closed");
		}
	}

	public function setSynchThreshold(s:Int):Void {
		onTimeGet.stop();
		onTimeGet = new Timer(s * 1000);
		onTimeGet.run = requestTime;
		settings.synchThreshold = s;
		Settings.write(settings);
	}

	public function toggleLeader():Void {
		// change button style before answer
		setLeaderButton(!personal.isLeader);
		final name = personal.isLeader ? "" : personal.name;
		send({
			type: SetLeader,
			setLeader: {
				clientName: name
			}
		});
	}

	public function removeLeader():Void {
		send({
			type: SetLeader,
			setLeader: {
				clientName: ""
			}
		});
	}

	public function toggleLeaderAndPause():Void {
		if (!isLeader()) {
			JsApi.once(SetLeader, event -> {
				final name = event.setLeader.clientName;
				if (name == getName()) player.pause();
			});
		}
		toggleLeader();
	}

	public function hasLeader():Bool {
		return clients.hasLeader();
	}

	public function hasLeaderOnPauseRequest():Bool {
		return config.requestLeaderOnPause;
	}

	public function hasUnpauseWithoutLeader():Bool {
		return config.unpauseWithoutLeader;
	}

	public function getTemplateUrl():String {
		return config.templateUrl;
	}

	public function getYoutubeApiKey():String {
		return config.youtubeApiKey;
	}

	public function getYoutubePlaylistLimit():Int {
		return config.youtubePlaylistLimit;
	}

	public function isAutoplayAllowed():Bool {
		final navigator:{
			getAutoplayPolicy:(type:String) -> Bool
		} = cast Browser.navigator;
		if (navigator.getAutoplayPolicy != null) return
			navigator.getAutoplayPolicy("mediaelement");
		return gotFirstPageInteraction;
	}

	public function isVerbose():Bool {
		return config.isVerbose;
	}

	function escapeRegExp(regex:String):String {
		return ~/([.*+?^${}()|[\]\\])/g.replace(regex, "\\$1");
	}

	@:generic
	public static inline function getEl<T:Element>(id:String):T {
		return cast document.querySelector(id);
	}
}
