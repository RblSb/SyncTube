package client;

import haxe.crypto.Sha256;
import haxe.Timer;
import js.html.MouseEvent;
import js.html.KeyboardEvent;
import js.html.Event;
import js.html.Element;
import haxe.Json;
import js.html.InputElement;
import js.html.WebSocket;
import js.Browser;
import js.Browser.document;
import js.lib.Date;
import Client.ClientData;
import Types.VideoData;
import Types.Config;
import Types.WsEvent;
using StringTools;
using ClientTools;

class Main {

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
	final onTimeGet = new Timer(2000);
	var onBlinkTab:Null<Timer>;

	static function main():Void new Main();

	public function new(?host:String, ?port:String) {
		player = new Player(this);
		if (host == null) host = Browser.location.hostname;
		if (host == "") host = "localhost";
		this.host = host;
		if (port == null) port = Browser.location.port;
		if (port == "") port = "80";

		initListeners();
		onTimeGet.run = () -> {
			if (player.isListEmpty()) return;
			send({type: GetTime});
		}
		document.onvisibilitychange = () -> {
			if (!document.hidden && onBlinkTab != null) {
				document.title = getPageTitle();
				onBlinkTab.stop();
				onBlinkTab = null;
			}
		}
		Lang.init("langs", () -> {
			openWebSocket(host, port);
		});
	}

	function openWebSocket(host:String, port:String):Void {
		ws = new WebSocket('ws://$host:$port');
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
		MobileView.init();

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
		ge("#mediaurl").onkeydown = function(e:KeyboardEvent) {
			if (e.keyCode == 13) addVideoUrl(true);
		}
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

	function addVideoUrl(atEnd:Bool):Void {
		final mediaUrl:InputElement = cast ge("#mediaurl");
		final checkbox:InputElement = cast ge("#addfromurl").querySelector(".add-temp");
		final isTemp = checkbox.checked;
		final url = mediaUrl.value;
		if (url.length == 0) return;
		mediaUrl.value = "";
		final url = ~/,(https?)/g.replace(url, "|$1");
		final links = url.split("|");
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
			send({
				type: AddVideo, addVideo: {
					item: {
						url: url,
						title: data.title,
						author: personal.name,
						duration: data.duration,
						isTemp: isTemp
					},
					atEnd: atEnd
			}});
			callback();
		});
	}

	public function toggleVideoElement():Bool {
		if (player.hasVideo()) player.removeVideo();
		else if (!player.isListEmpty()) {
			player.setVideo(player.getItemPos());
		}
		return player.hasVideo();
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
		final t:String = cast data.type;
		final t = t.charAt(0).toLowerCase() + t.substr(1);
		trace('Event: ${data.type}', untyped data[t]);
		switch (data.type) {
			case Connected:
				onConnected(data);
				onTimeGet.run();

			case Login:
				onLogin(data.login.clients, data.login.clientName);

			case PasswordRequest:
				showGuestPasswordPanel();

			case LoginError:
				final text = Lang.get("usernameError")
					.replace("$MAX", '${config.maxLoginLength}');
				serverMessage(4, text);
				showGuestLoginPanel();

			case Logout:
				updateClients(data.logout.clients);
				personal = new Client(data.logout.clientName, 0);
				showGuestLoginPanel();

			case UpdateClients:
				updateClients(data.updateClients.clients);
				personal = clients.getByName(personal.name, personal);

			case Message:
				addMessage(data.message.clientName, data.message.text);

			case AddVideo:
				player.addVideoItem(data.addVideo.item, data.addVideo.atEnd);
				if (player.itemsLength() == 1) player.setVideo(0);

			case VideoLoaded:
				player.setTime(0);
				player.play();

			case RemoveVideo:
				player.removeItem(data.removeVideo.url);
				if (player.isListEmpty()) player.pause();

			case SkipVideo:
				player.skipItem(data.skipVideo.url);
				if (player.isListEmpty()) player.pause();

			case Pause:
				if (isLeader()) return;
				player.pause();
				player.setTime(data.pause.time);

			case Play:
				if (isLeader()) return;
				player.setTime(data.play.time);
				player.play();

			case GetTime:
				final newTime = data.getTime.time;
				final time = player.getTime();
				if (isLeader()) {
					// if video is loading on leader
					// move other clients back in time
					if (Math.abs(time - newTime) < 2) return;
					player.setTime(time, false);
					return;
				}
				if (!data.getTime.paused) player.play();
				else player.pause();
				if (Math.abs(time - newTime) < 2) return;
				player.setTime(newTime);

			case SetTime:
				final newTime = data.setTime.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) < 2) return;
				player.setTime(newTime);

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
		final guestPass:InputElement = cast ge("#guestpass");
		if (config.salt != null && guestPass.value.length > 0) {
			userLogin(guestName.value, guestPass.value);
		} else {
			guestLogin(guestName.value);
		}
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
	}

	public function userLogin(name:String, password:String):Void {
		if (config.salt == null) return;
		if (password.length == 0) return;
		if (name.length == 0) return;
		send({
			type: Login, login: {
				clientName: name,
				passHash: Sha256.encode(password + config.salt)
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
			filters.push({
				regex: new EReg(escapeRegExp(emote.name), "g"),
				replace: '<img class="channel-emote" src="${emote.image}" title="${emote.name}"/>'
			});
		}
		final smilesWrap = ge("#smileswrap");
		smilesWrap.onclick = (e:MouseEvent) -> {
			final el:Element = cast e.target;
			final form:InputElement = cast ge("#chatline");
			form.value += ' ${el.title}';
			form.focus();
		}
		smilesWrap.textContent = "";
		for (emote in config.emotes) {
			final img = document.createImageElement();
			img.className = "smile-preview";
			img.src = emote.image;
			img.title = emote.name;
			smilesWrap.appendChild(img);
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
		ge("#guestlogin").style.display = "block";
		ge("#guestpassword").style.display = "none";
		ge("#chatline").style.display = "none";
		ge("#exitBtn").textContent = Lang.get("login");
		Browser.window.dispatchEvent(new Event("resize"));
	}

	function hideGuestLoginPanel():Void {
		ge("#guestlogin").style.display = "none";
		ge("#guestpassword").style.display = "none";
		ge("#chatline").style.display = "block";
		ge("#exitBtn").textContent = Lang.get("exit");
		if (isAdmin()) ge("#clearchatbtn").style.display = "inline-block";
		Browser.window.dispatchEvent(new Event("resize"));
	}

	function showGuestPasswordPanel():Void {
		ge("#guestlogin").style.display = "none";
		ge("#chatline").style.display = "none";
		ge("#guestpassword").style.display = "block";
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

	function serverMessage(type:Int, ?text:String):Void {
		final msgBuf = ge("#messagebuffer");
		final div = document.createDivElement();
		final time = "[" + new Date().toTimeString().split(" ")[0] + "] ";
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
				div.textContent = time + text;
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
			if (client.isLeader) list.add('<span class="glyphicon glyphicon-star-empty"></span>');
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

		final tstamp = document.createSpanElement();
		tstamp.className = "timestamp";
		if (time == null) time = "[" + new Date().toTimeString().split(" ")[0] + "] ";
		tstamp.textContent = time;

		final nameDiv = document.createElement("strong");
		nameDiv.className = "username";
		nameDiv.textContent = name + ": ";

		final textDiv = document.createSpanElement();
		text = text.htmlEscape();

		if (text.startsWith("/")) {
			if (name == personal.name) handleCommands(text.substr(1));
		} else {
			for (filter in filters) {
				text = filter.regex.replace(text, filter.replace);
			}
		}
		textDiv.innerHTML = text;

		final isInChatEnd = msgBuf.scrollHeight - msgBuf.scrollTop == msgBuf.clientHeight;
		userDiv.appendChild(tstamp);
		userDiv.appendChild(nameDiv);
		userDiv.appendChild(textDiv);
		msgBuf.appendChild(userDiv);
		if (isInChatEnd) {
			while (msgBuf.children.length > 200) msgBuf.removeChild(msgBuf.firstChild);
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
		if (name == personal.name) {
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
		if (document.hidden && onBlinkTab == null) {
			onBlinkTab = new Timer(1000);
			onBlinkTab.run = () -> {
				if (document.title.startsWith(pageTitle))
					document.title = "*Chat*";
				else document.title = getPageTitle();
			}
			onBlinkTab.run();
		}
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

	function setLeaderButton(flag:Bool):Void {
		final leaderBtn = ge("#leader_btn");
		if (isLeader()) {
			leaderBtn.classList.add("label-success");
		} else leaderBtn.classList.remove("label-success");
	}

	function escapeRegExp(regex:String):String {
		return ~/([.*+?^${}()|[\]\\])/g.replace(regex, "\\$1");
	}

	public static inline function ge(id:String):Element {
		return document.querySelector(id);
	}

}
