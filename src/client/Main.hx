package client;

import haxe.crypto.Sha256;
import haxe.Timer;
import haxe.Json;
import js.html.MouseEvent;
import js.html.KeyboardEvent;
import js.html.Event;
import js.html.Element;
import js.html.VideoElement;
import js.html.InputElement;
import js.html.WebSocket;
import js.Browser;
import js.Browser.document;
import js.Browser.window;
import Client.ClientData;
import Types.VideoData;
import Types.Config;
import Types.WsEvent;
using StringTools;
using ClientTools;

class Main {

	static inline var SETTINGS_VERSION = 2;
	public final settings:ClientSettings;
	public var isSyncActive = true;
	public var forceSyncNextTick = false;
	final clients:Array<Client> = [];
	var pageTitle = document.title;
	final host:String;
	var globalIp = "";
	var config:Null<Config>;
	final filters:Array<{regex:EReg, replace:String}> = [];
	var personal = new Client("Unknown", 0);
	var isConnected = false;
	var ws:WebSocket;
	final player:Player;
	var onTimeGet:Timer;
	var onBlinkTab:Null<Timer>;

	static function main():Void new Main();

	function new(?host:String, ?port:String) {
		player = new Player(this);
		if (host == null) host = Browser.location.hostname;
		if (host == "") host = "localhost";
		this.host = host;
		if (port == null) port = Browser.location.port;
		if (port == "") port = "80";

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
			openWebSocket(host, port);
		});
		JsApi.init(this, player);
	}

	function settingsPatcher(data:Any, version:Int):Any {
		switch (version) {
			case 1:
				final data:ClientSettings = data;
				data.hotkeysEnabled = true;
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

	function openWebSocket(host:String, port:String):Void {
		var protocol = "ws:";
		if (Browser.location.protocol == "https:") protocol = "wss:";
		ws = new WebSocket('$protocol//$host:$port');
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
			Timer.delay(() -> openWebSocket(host, port), 2000);
		}
	}

	function initListeners():Void {
		Buttons.init(this);

		ge("#leader_btn").onclick = e -> {
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

		ge("#ce_queue_next").onclick = e -> addIframe(false);
		ge("#ce_queue_end").onclick = e -> addIframe(true);
		ge("#customembed-title").onkeydown = (e:KeyboardEvent) -> {
			if (e.keyCode == KeyCode.Return) {
				addIframe(true);
				e.preventDefault();
			}
		}
		ge("#customembed-content").onkeydown =
			ge("#customembed-title").onkeydown;
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
		final checkbox:InputElement = cast ge("#addfromurl").querySelector(".add-temp");
		final isTemp = checkbox.checked;
		final url = mediaUrl.value;
		if (url.length == 0) return;
		mediaUrl.value = "";
		InputWithHistory.pushIfNotLast(settings.latestLinks, url);
		Settings.write(settings);
		final url = ~/, ?(https?)/g.replace(url, "|$1");
		final links = url.split("|");
		handleUrlMasks(links);
		// if videos added as next, we need to load them in reverse order
		if (!atEnd) {
			// except first item when list empty
			var first:Null<String> = null;
			if (player.isListEmpty()) first = links.shift();
			links.reverse();
			if (player.isListEmpty()) links.unshift(first);
		}
		addVideoArray(links, atEnd, isTemp);
	}

	function addVideoArray(links:Array<String>, atEnd:Bool, isTemp:Bool):Void {
		if (links.length == 0) return;
		final link = links.shift();
		addVideo(link, atEnd, isTemp, () -> addVideoArray(links, atEnd, isTemp));
	}

	function addVideo(url:String, atEnd:Bool, isTemp:Bool, callback:()->Void):Void {
		final protocol = Browser.location.protocol;
		if (url.startsWith("/")) {
			final host = Browser.location.hostname;
			final port = Browser.location.port;
			url = '$protocol//$host:$port$url';
		}
		if (!url.startsWith("http")) url = '$protocol//$url';

		player.getVideoData(url, (data:VideoData) -> {
			if (data.duration == 0) {
				serverMessage(4, Lang.get("addVideoError"));
				return;
			}
			if (data.title == null) data.title = Lang.get("rawVideo");
			if (data.url == null) data.url = url;
			send({
				type: AddVideo, addVideo: {
					item: {
						url: data.url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp,
						isIframe: data.isIframe == true
					},
					atEnd: atEnd
			}});
			callback();
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
		player.getIframeData(iframe, (data:VideoData) -> {
			if (data.duration == 0) {
				serverMessage(4, Lang.get("addVideoError"));
				return;
			}
			if (title.length > 0) data.title = title;
			if (data.title == null) data.title = "Custom Media";
			if (data.url == null) data.url = iframe;
			send({
				type: AddVideo, addVideo: {
					item: {
						url: data.url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp,
						isIframe: true
					},
					atEnd: atEnd
			}});
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
				settings.name = "";
				settings.hash = "";
				Settings.write(settings);
				showGuestLoginPanel();

			case UpdateClients:
				updateClients(data.updateClients.clients);
				personal = clients.getByName(personal.name, personal);

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
				player.setTime(data.play.time);
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
				player.setTime(newTime);

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
				player.setTime(data.rewind.time);

			case SetLeader:
				clients.setLeader(data.setLeader.clientName);
				updateUserList();
				setLeaderButton(isLeader());
				if (isLeader()) player.setTime(player.getTime(), false);

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
	}

	public function guestLogin(name:String):Void {
		if (name.length == 0) return;
		send({
			type: Login, login: {
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
			type: Login, login: {
				clientName: name,
				passHash: hash
			}
		});
	}

	function setConfig(config:Config):Void {
		this.config = config;
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
		if (isAdmin()) ge("#adminMenu").style.display = "block";
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

	public function serverMessage(type:Int, ?text:String, isText = true):Void {
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
			final klass = client.isAdmin ? "userlist_owner" : "";
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

	function addMessage(name:String, text:String, ?time:String):Void {
		final msgBuf = ge("#messagebuffer");
		final userDiv = document.createDivElement();
		userDiv.className = 'chat-msg-$name';

		final headDiv = document.createDivElement();
		headDiv.className = "head";

		final tstamp = document.createSpanElement();
		tstamp.className = "timestamp";
		if (time == null) time = Date.now().toString().split(" ")[1];
		tstamp.textContent = time;

		final nameDiv = document.createElement("strong");
		nameDiv.className = "username";
		nameDiv.textContent = name;

		final textDiv = document.createDivElement();
		textDiv.className = "text";
		text = text.htmlEscape();

		if (text.startsWith("/")) {
			if (name == personal.name) handleCommands(text.substr(1));
		} else {
			for (filter in filters) {
				text = filter.regex.replace(text, filter.replace);
			}
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
			while (msgBuf.children.length > 200) msgBuf.removeChild(msgBuf.firstChild);
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
			emoteMaxSize = Std.parseInt(window.getComputedStyle(el).getPropertyValue("max-width"));
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

	final matchNumbers = ~/^-?[0-9]+$/;

	function handleCommands(text:String):Void {
		switch (text) {
			case "clear":
				if (isAdmin()) send({type: ClearChat});
		}
		if (matchNumbers.match(text)) {
			send({type: Rewind, rewind: {
				time: Std.parseInt(text)
			}});
		}
	}

	public function blinkTabWithTitle(title:String):Void {
		if (!document.hidden) return;
		if (onBlinkTab != null) onBlinkTab.stop();
		onBlinkTab = new Timer(1000);
		onBlinkTab.run = () -> {
			if (document.title.startsWith(pageTitle))
				document.title = title;
			else document.title = getPageTitle();
		}
		onBlinkTab.run();
	}

	function setLeaderButton(flag:Bool):Void {
		final leaderBtn = ge("#leader_btn");
		if (flag) leaderBtn.classList.add("success-bg");
		else leaderBtn.classList.remove("success-bg");
	}

	function setPlaylistLock(isOpen:Bool):Void {
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

	public function getTemplateUrl():String {
		return config.templateUrl;
	}

	public function getYoutubeApiKey():String {
		return config.youtubeApiKey;
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
