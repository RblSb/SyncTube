package client;

import Client.ClientData;
import Types.Config;
import Types.Permission;
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
import js.html.VideoElement;
import js.html.WebSocket;

using ClientTools;
using StringTools;

class Main {
	static inline var SETTINGS_VERSION = 3;

	public final settings:ClientSettings;
	public var isSyncActive = true;
	public var forceSyncNextTick = false;
	public final host:String;
	public var globalIp(default, null) = "";
	public var isPlaylistOpen = true;

	final clients:Array<Client> = [];
	var pageTitle = document.title;
	var config:Null<Config>;
	final filters:Array<{regex:EReg, replace:String}> = [];
	var personal = new Client("Unknown", 0);
	var isConnected = false;
	var disabledReconnection = false;
	var ws:WebSocket;
	final player:Player;
	var onTimeGet:Timer;
	var onBlinkTab:Null<Timer>;

	static function main():Void {
		new Main();
	}

	function new() {
		player = new Player(this);
		host = Browser.location.hostname;
		if (host == "") host = "localhost";

		final defaults:ClientSettings = {
			version: SETTINGS_VERSION,
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
			hotkeysEnabled: true
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
	}

	function settingsPatcher(data:Any, version:Int):Any {
		switch (version) {
			case 1:
				final data:ClientSettings = data;
				data.hotkeysEnabled = true;
			case 2:
				final data:ClientSettings = data;
				data.latestSubs = [];
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
		ws = new WebSocket('$protocol//$host$colonPort$path');
		ws.onmessage = onMessage;
		ws.onopen = () -> {
			serverMessage(1);
			isConnected = true;
		}
		ws.onclose = () -> {
			// if initial connection refused
			// or server/client offline
			if (isConnected) serverMessage(2);
			isConnected = false;
			player.pause();
			if (disabledReconnection) return;
			Timer.delay(openWebSocket, 2000);
		}
	}

	function initListeners():Void {
		Buttons.init(this);

		ge("#leader_btn").onclick = toggleLeader;
		final voteSkip = ge("#voteskip");
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

		ge("#queue_next").onclick = e -> addVideoUrl(false);
		ge("#queue_end").onclick = e -> addVideoUrl(true);
		new InputWithHistory(cast ge("#mediaurl"), settings.latestLinks, 10, value -> {
			addVideoUrl(true);
			return false;
		});
		ge("#mediatitle").onkeydown = (e:KeyboardEvent) -> {
			if (e.keyCode == KeyCode.Return) addVideoUrl(true);
		}
		new InputWithHistory(cast ge("#subsurl"), settings.latestSubs, 10, value -> {
			addVideoUrl(true);
			return false;
		});

		ge("#ce_queue_next").onclick = e -> addIframe(false);
		ge("#ce_queue_end").onclick = e -> addIframe(true);
		ge("#customembed-title").onkeydown = (e:KeyboardEvent) -> {
			if (e.keyCode == KeyCode.Return) {
				addIframe(true);
				e.preventDefault();
			}
		}
		ge("#customembed-content").onkeydown = ge("#customembed-title").onkeydown;
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

	final mask = ~/\${([0-9]+)-([0-9]+)}/g;

	function handleUrlMasks(links:Array<String>):Void {
		for (link in links) {
			if (!mask.match(link)) continue;
			final start = Std.parseInt(mask.matched(1));
			var end = Std.parseInt(mask.matched(2));
			if (Math.abs(start - end) > 100) continue;
			final step = end > start ? -1 : 1;
			final i = links.indexOf(link);
			links.remove(link);
			while (end != start + step) {
				links.insert(i, mask.replace(link, '$end'));
				end += step;
			}
		}
	}

	function addVideoUrl(atEnd:Bool):Void {
		final mediaUrl:InputElement = cast ge("#mediaurl");
		final subsUrl:InputElement = cast ge("#subsurl");
		final checkbox:InputElement = cast ge("#addfromurl").querySelector(".add-temp");
		final isTemp = checkbox.checked;
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
		addVideoArray(links, atEnd, isTemp);
	}

	public function isRawPlayerLink(url:String):Bool {
		return player.isRawPlayerLink(url);
	}

	public function isSingleVideoLink(url:String):Bool {
		if (~/, ?(https?)/g.match(url)) return false;
		if (mask.match(url)) return false;
		return true;
	}

	public function sortItemsForQueueNext<T>(items:Array<T>):Void {
		if (items.length == 0) return;
		// except first item when list empty
		var first:Null<T> = null;
		if (player.isListEmpty()) first = items.shift();
		items.reverse();
		if (first != null) items.unshift(first);
	}

	function addVideoArray(links:Array<String>, atEnd:Bool, isTemp:Bool):Void {
		if (links.length == 0) return;
		final link = links.shift();
		addVideo(link, atEnd, isTemp, () -> addVideoArray(links, atEnd, isTemp));
	}

	public function addVideo(url:String, atEnd:Bool, isTemp:Bool, ?callback:() -> Void):Void {
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
				serverMessage(4, Lang.get("addVideoError"));
				return;
			}
			if (data.title == null) data.title = Lang.get("rawVideo");
			if (data.url == null) data.url = url;
			send({
				type: AddVideo,
				addVideo: {
					item: {
						url: data.url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp,
						subs: data.subs,
						isIframe: data.isIframe == true
					},
					atEnd: atEnd
				}
			});
			if (callback != null) callback();
		});
	}

	function addIframe(atEnd:Bool):Void {
		final iframeCode:InputElement = cast ge("#customembed-content");
		final iframe = iframeCode.value;
		if (iframe.length == 0) return;
		iframeCode.value = "";
		final mediaTitle:InputElement = cast ge("#customembed-title");
		final title = mediaTitle.value;
		mediaTitle.value = "";
		final checkbox:InputElement = cast ge("#customembed").querySelector(".add-temp");
		final isTemp = checkbox.checked;
		final obj:VideoDataRequest = {
			url: iframe,
			atEnd: atEnd
		};
		player.getIframeData(obj, (data:VideoData) -> {
			if (data.duration == 0) {
				serverMessage(4, Lang.get("addVideoError"));
				return;
			}
			if (title.length > 0) data.title = title;
			if (data.title == null) data.title = "Custom Media";
			if (data.url == null) data.url = iframe;
			send({
				type: AddVideo,
				addVideo: {
					item: {
						url: data.url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp,
						isIframe: true
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
		if (player.hasVideo()) player.removeVideo();
		else if (!player.isListEmpty()) {
			player.setVideo(player.getItemPos());
		}
		return player.hasVideo();
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
		return url.replace(globalIp, host);
	}

	function onMessage(e):Void {
		final data:WsEvent = Json.parse(e.data);
		if (config != null && config.isVerbose) {
			final t:String = cast data.type;
			final t = t.charAt(0).toLowerCase() + t.substr(1);
			trace('Event: ${data.type}', Reflect.field(data, t));
		}
		JsApi.fireOnceEvent(data);
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
				serverMessage(4, text);

			case AddVideo:
				player.addVideoItem(data.addVideo.item, data.addVideo.atEnd);
				if (player.itemsLength() == 1) player.setVideo(0);

			case VideoLoaded:
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
				player.setPauseIndicator(false);
				if (isLeader()) return;
				player.pause();
				player.setTime(data.pause.time);

			case Play:
				player.setPauseIndicator(true);
				if (isLeader()) return;
				final synchThreshold = settings.synchThreshold;
				final newTime = data.play.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) >= synchThreshold) {
					player.setTime(newTime);
				}
				player.play();

			case GetTime:
				if (data.getTime.paused == null) data.getTime.paused = false;
				if (data.getTime.rate == null) data.getTime.rate = 1;

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
				if (!data.getTime.paused) player.play();
				else player.pause();
				player.setPauseIndicator(!data.getTime.paused);
				if (Math.abs(time - newTime) < synchThreshold) return;
				// +0.5s for buffering
				if (!data.getTime.paused) player.setTime(newTime + 0.5);
				else player.setTime(newTime);

			case SetTime:
				final synchThreshold = settings.synchThreshold;
				final newTime = data.setTime.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) < synchThreshold) return;
				player.setTime(newTime);

			case SetRate:
				if (isLeader()) return;
				player.setPlaybackRate(data.setRate.rate);

			case Rewind:
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

	function onConnected(data:WsEvent):Void {
		final connected = data.connected;
		globalIp = connected.globalIp;
		setConfig(connected.config);
		if (connected.isUnknownClient) {
			updateClients(connected.clients);
			personal = clients.getByName(connected.clientName, personal);
			showGuestLoginPanel();
		} else {
			onLogin(connected.clients, connected.clientName);
		}
		final guestName:InputElement = cast ge("#guestname");
		var name = settings.name;
		if (name.length == 0) name = guestName.value;
		final hash = settings.hash;
		if (hash.length > 0) loginRequest(name, hash);
		else guestLogin(name);

		setLeaderButton(isLeader());
		setPlaylistLock(connected.isPlaylistOpen);
		clearChat();
		serverMessage(1);
		for (message in connected.history) {
			addMessage(message.name, message.text, message.time);
		}
		player.setItems(connected.videoList, connected.itemPos);
		onUserGroupChanged();
	}

	function onUserGroupChanged():Void {
		final button:ButtonElement = cast ge("#queue_next");
		if (personal.hasPermission(ChangeOrderPerm, config.permissions)) {
			button.disabled = false;
		} else {
			button.disabled = true;
		}
		final adminMenu = ge("#adminMenu");
		if (isAdmin()) adminMenu.style.display = "block";
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
		if (Utils.isTouch()) config.requestLeaderOnPause = false;
		pageTitle = config.channelName;
		final login:InputElement = cast ge("#guestname");
		login.maxLength = config.maxLoginLength;
		final form:InputElement = cast ge("#chatline");
		form.maxLength = config.maxMessageLength;

		filters.resize(0);
		for (filter in config.filters) {
			filters.push({
				regex: new EReg(filter.regex, filter.flags),
				replace: filter.replace
			});
		}
		for (emote in config.emotes) {
			final tag = emote.image.endsWith("mp4") ? 'video autoplay="" loop="" muted=""' : "img";
			filters.push({
				regex: new EReg("(^| )" + escapeRegExp(emote.name) + "(?!\\S)", "g"),
				replace: '$1<$tag class="channel-emote" src="${emote.image}" title="${emote.name}"/>'
			});
		}
		ge("#smilesbtn").classList.remove("active");
		final smilesWrap = ge("#smileswrap");
		smilesWrap.style.display = "none";
		smilesWrap.onclick = (e:MouseEvent) -> {
			final el:Element = cast e.target;
			if (el == smilesWrap) return;
			final form:InputElement = cast ge("#chatline");
			form.value += ' ${el.title}';
			form.focus();
		}
		smilesWrap.textContent = "";
		for (emote in config.emotes) {
			final tag = emote.image.endsWith("mp4") ? "video" : "img";
			final el = document.createElement(tag);
			el.className = "smile-preview";
			el.dataset.src = emote.image;
			el.title = emote.name;
			smilesWrap.appendChild(el);
		}
	}

	function onLogin(data:Array<ClientData>, clientName:String):Void {
		updateClients(data);
		final newPersonal = clients.getByName(clientName);
		if (newPersonal == null) return;
		personal = newPersonal;
		onUserGroupChanged();
		hideGuestLoginPanel();
	}

	function showGuestLoginPanel():Void {
		ge("#guestlogin").style.display = "flex";
		ge("#guestpassword").style.display = "none";
		ge("#chatbox").style.display = "none";
		ge("#exitBtn").textContent = Lang.get("login");
	}

	function hideGuestLoginPanel():Void {
		ge("#guestlogin").style.display = "none";
		ge("#guestpassword").style.display = "none";
		ge("#chatbox").style.display = "flex";
		ge("#exitBtn").textContent = Lang.get("exit");
	}

	function showGuestPasswordPanel():Void {
		ge("#guestlogin").style.display = "none";
		ge("#chatbox").style.display = "none";
		ge("#guestpassword").style.display = "flex";
		(cast ge("#guestpass") : InputElement).type = "password";
		ge("#guestpass_icon").setAttribute("name", "eye");
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

	public static function serverMessage(type:Int, ?text:String, isText = true):Void {
		final msgBuf = ge("#messagebuffer");
		final div = document.createDivElement();
		final time = Date.now().toString().split(" ")[1];
		switch (type) {
			case 1:
				div.className = "server-msg-reconnect";
				div.textContent = Lang.get("msgConnected");
			case 2:
				div.className = "server-msg-disconnect";
				div.textContent = Lang.get("msgDisconnected");
			case 3:
				div.className = "server-whisper";
				div.textContent = time + text + " " + Lang.get("entered");
			case 4:
				div.className = "server-whisper";
				div.innerHTML = '<div class="head">
					<div class="server-whisper"></div>
					<span class="timestamp">$time</span>
				</div>';
				final textDiv = div.querySelector(".server-whisper");
				if (isText) textDiv.textContent = text;
				else textDiv.innerHTML = text;
			default:
		}
		msgBuf.appendChild(div);
		msgBuf.scrollTop = msgBuf.scrollHeight;
	}

	function updateUserList():Void {
		final userCount = ge("#usercount");
		userCount.textContent = clients.length + " " + Lang.get("online");
		document.title = getPageTitle();

		final list = new StringBuf();
		for (client in clients) {
			list.add('<div class="userlist_item">');
			if (client.isLeader) list.add('<ion-icon name="play"></ion-icon>');
			var klass = client.isBanned ? "userlist_banned" : "";
			if (client.isAdmin) klass += " userlist_owner";
			list.add('<span class="$klass">${client.name}</span></div>');
		}
		final userlist = ge("#userlist");
		userlist.innerHTML = list.toString();
	}

	function getPageTitle():String {
		return '$pageTitle (${clients.length})';
	}

	function clearChat():Void {
		ge("#messagebuffer").textContent = "";
	}

	function getLocalDateFromUtc(utcDate:String):String {
		final date = Date.fromString(utcDate);
		final localTime = date.getTime() - date.getTimezoneOffset() * 60 * 1000;
		return Date.fromTime(localTime).toString();
	}

	function addMessage(name:String, text:String, ?date:String):Void {
		final msgBuf = ge("#messagebuffer");
		final userDiv = document.createDivElement();
		userDiv.className = 'chat-msg-$name';

		final headDiv = document.createDivElement();
		headDiv.className = "head";

		final tstamp = document.createSpanElement();
		tstamp.className = "timestamp";
		if (date == null) date = Date.now().toString();
		else date = getLocalDateFromUtc(date);
		final time = date.split(" ")[1];
		tstamp.textContent = time == null ? date : time;
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
		final isInChatEnd = msgBuf.scrollTop + msgBuf.clientHeight >= msgBuf.scrollHeight - 1;

		if (isInChatEnd) { // scroll chat to end after images loaded
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
		msgBuf.appendChild(userDiv);
		if (isInChatEnd) {
			while (msgBuf.children.length > 200) {
				msgBuf.removeChild(msgBuf.firstChild);
			}
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
		if (name == personal.name) {
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
		if (onBlinkTab == null) blinkTabWithTitle("*Chat*");
	}

	function onChatImageLoaded(e:Event):Void {
		scrollChatToEnd();
		(cast e.target : Element).onload = null;
	}

	var emoteMaxSize:Null<Int>;

	function onChatVideoLoaded(e:Event):Void {
		final el:VideoElement = cast e.target;
		if (emoteMaxSize == null) {
			emoteMaxSize = Std.parseInt(window.getComputedStyle(el)
				.getPropertyValue("max-width"));
		}
		// fixes default video tag size in chat when tab unloads videos in background
		// (some browsers optimization i guess)
		final max = emoteMaxSize;
		final ratio = Math.min(max / el.videoWidth, max / el.videoHeight);
		el.style.width = '${el.videoWidth * ratio}px';
		el.style.height = '${el.videoHeight * ratio}px';
		scrollChatToEnd();
		el.onloadedmetadata = null;
	}

	public function scrollChatToEnd():Void {
		final msgBuf = ge("#messagebuffer");
		msgBuf.scrollTop = msgBuf.scrollHeight;
	}

	/* Returns `true` if text should not be sent to chat */
	public function handleCommands(command:String):Bool {
		if (!command.startsWith("/")) return false;
		final args = command.trim().split(" ");
		command = args.shift().substr(1);
		if (command.length == 0) return false;

		switch (command) {
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
		final leaderBtn = ge("#leader_btn");
		if (flag) leaderBtn.classList.add("success-bg");
		else leaderBtn.classList.remove("success-bg");
	}

	function setPlaylistLock(isOpen:Bool):Void {
		isPlaylistOpen = isOpen;
		final lockPlaylist = ge("#lockplaylist");
		final icon = lockPlaylist.firstElementChild;
		if (isOpen) {
			lockPlaylist.title = Lang.get("playlistOpen");
			lockPlaylist.classList.add("btn-success");
			lockPlaylist.classList.add("success");
			lockPlaylist.classList.remove("danger");
			icon.setAttribute("name", "lock-open");
		} else {
			lockPlaylist.title = Lang.get("playlistLocked");
			lockPlaylist.classList.add("btn-danger");
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

	public function hasLeader():Bool {
		return clients.hasLeader();
	}

	public function hasLeaderOnPauseRequest():Bool {
		return config.requestLeaderOnPause;
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

	public function isVerbose():Bool {
		return config.isVerbose;
	}

	function escapeRegExp(regex:String):String {
		return ~/([.*+?^${}()|[\]\\])/g.replace(regex, "\\$1");
	}

	public static inline function ge(id:String):Element {
		return document.querySelector(id);
	}
}
