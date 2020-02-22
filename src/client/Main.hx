package client;

import haxe.Timer;
import js.html.MouseEvent;
import js.html.ButtonElement;
import js.html.KeyboardEvent;
import js.html.Element;
import haxe.Json;
import js.html.InputElement;
import js.html.WebSocket;
import js.Browser;
import js.Browser.document;
import js.lib.Date;
import Client.ClientData;
import Types;
using StringTools;
using ClientTools;

class Main {

	final clients:Array<Client> = [];
	var pageTitle = document.title;
	var config:Null<Config>;
	final filters:Array<{regex:EReg, replace:String}> = [];
	var personal = new Client("Unknown", 0);
	var isConnected = false;
	var ws:WebSocket;
	final player:Player;
	final onTimeGet = new Timer(2000);
	var onBlinkTab:Null<Timer>;

	static function main():Void new Main();

	public function new(?host:String, port = 4201) {
		player = new Player(this);
		if (host == null) host = Browser.location.hostname;
		if (host == "") host = "localhost";

		initListeners();
		onTimeGet.run = () -> send({type: GetTime});
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

	function openWebSocket(host:String, port:Int):Void {
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

		final leaderBtn = ge("#leader_btn");
		leaderBtn.onclick = (e) -> {
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

		// TODO next/end
		ge("#queue_next").onclick = (e:MouseEvent) -> addVideoUrl();
		ge("#queue_end").onclick = (e:MouseEvent) -> addVideoUrl();
		ge("#mediaurl").onkeydown = function(e:KeyboardEvent) {
			if (e.keyCode == 13) addVideoUrl();
		}
	}

	public inline function isLeader():Bool {
		return personal.isLeader;
	}

	public inline function isAdmin():Bool {
		return personal.isAdmin;
	}

	function addVideoUrl():Void {
		final mediaUrl:InputElement = cast ge("#mediaurl");
		final url = mediaUrl.value;
		var name = url.substr(url.lastIndexOf('/') + 1);
		final matchName = ~/^(.+)\./;
		if (matchName.match(name)) name = matchName.matched(1);
		else name = Lang.get("rawVideo");

		getRemoteVideoDuration(mediaUrl.value, (duration:Float) -> {
			send({
				type: AddVideo, addVideo: {
					item: {
						url: url,
						title: name,
						author: personal.name,
						duration: duration
					}
				}});
		});
		mediaUrl.value = "";
	}

	function getRemoteVideoDuration(src:String, callback:(duration:Float)->Void):Void {
		final player:Element = ge("#ytapiplayer");
		final video = document.createVideoElement();
		video.src = src;
		// TODO catch errors on AddVideo and getRemoteVideoDuration
		video.onerror = e -> {
			callback(0);
		}
		video.onloadedmetadata = () -> {
			player.removeChild(video);
			callback(video.duration);
		}
		prepend(player, video);
	}

	function prepend(parent:Element, child:Element):Void {
		if (parent.firstChild == null) parent.appendChild(child);
		else parent.insertBefore(child, parent.firstChild);
	}

	function onMessage(e):Void {
		final data:WsEvent = Json.parse(e.data);
		final t:String = cast data.type;
		final t = t.charAt(0).toLowerCase() + t.substr(1);
		trace('Event: ${data.type}', untyped data[t]);
		switch (data.type) {
			case Connected:
				onConnected(data);
			case Login:
				onLogin(data.login.clients, data.login.clientName);
			case LoginError:
				final text = Lang.get("usernameError")
					.replace("$MAX", '${config.maxLoginLength}');
				serverMessage(4, text);
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
				if (player.isListEmpty()) player.setVideo(data.addVideo.item);
				player.addVideoItem(data.addVideo.item);
			case VideoLoaded:
				player.setTime(0);
				player.play();
			case RemoveVideo:
				player.removeItem(data.removeVideo.url);
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
				if (Math.abs(time - newTime) < 2) return;
				player.setTime(newTime);
				if (!data.getTime.paused) player.play();
				else player.pause();
			case SetTime:
				final newTime = data.setTime.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) < 2) return;
				player.setTime(newTime);
			case SetLeader:
				clients.setLeader(data.setLeader.clientName);
				updateUserList();
				setLeaderButton(isLeader());
				if (isLeader()) player.setTime(player.getTime(), false);
			case ClearChat:
				ge("#messagebuffer").innerHTML = "";
		}
	}

	function onConnected(data:WsEvent):Void {
		final connected = data.connected;
		setConfig(connected.config);
		if (connected.isUnknownClient) {
			updateClients(connected.clients);
			personal = clients.getByName(connected.clientName, personal);
			showGuestLoginPanel();
		} else {
			onLogin(connected.clients, connected.clientName);
		}
		final guestName:InputElement = cast ge("#guestname");
		if (guestName.value.length > 0) send({
			type: Login,
			login: {
				clientName: guestName.value
			}
		});
		for (message in connected.history) {
			addMessage(message.name, message.text, message.time);
		}
		final list = connected.videoList;
		if (list.length == 0) return;
		player.setVideo(list[0]);
		for (video in connected.videoList) {
			player.addVideoItem(video);
		}
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
		smilesWrap.innerHTML = "";
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
		ge("#chatline").style.display = "none";
	}

	function hideGuestLoginPanel():Void {
		ge("#guestlogin").style.display = "none";
		ge("#chatline").style.display = "block";
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
				div.innerHTML = Lang.get("msgConnected");
			case 2:
				div.className = "server-msg-disconnect";
				div.innerHTML = Lang.get("msgDisconnected");
			case 3:
				div.className = "server-whisper";
				div.innerHTML = time + text + " " + Lang.get("entered");
			case 4:
				div.className = "server-whisper";
				div.innerHTML = time + text;
			default:
		}
		msgBuf.appendChild(div);
		msgBuf.scrollTop = msgBuf.scrollHeight;
	}

	function updateUserList():Void {
		final userCount = ge("#usercount");
		userCount.innerHTML = clients.length + " " + Lang.get("online");
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

	function addMessage(name:String, text:String, ?time:String):Void {
		final msgBuf = ge("#messagebuffer");
		final userDiv = document.createDivElement();
		userDiv.className = 'chat-msg-$name';

		final tstamp = document.createSpanElement();
		tstamp.className = "timestamp";
		if (time == null) time = "[" + new Date().toTimeString().split(" ")[0] + "] ";
		tstamp.innerHTML = time;

		final nameDiv = document.createElement("strong");
		nameDiv.className = "username";
		nameDiv.innerHTML = name + ": ";

		final textDiv = document.createSpanElement();
		for (filter in filters) {
			text = filter.regex.replace(text, filter.replace);
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
		if (personal.name == name) {
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
