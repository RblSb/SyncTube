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
using ClientTools;

class Main {

	final clients:Array<Client> = [];
	final personalHistory:Array<String> = [];
	var personal:Null<Client>;
	var personalHistoryId = -1;
	var isConnected = false;
	var ws:WebSocket;
	final player:Player;
	final onTimeGet = new Timer(2000);

	static function main():Void new Main();

	public function new(?host:String, port = 4201) {
		player = new Player(this);
		if (host == null) host = Browser.location.hostname;
		if (host == "") host = "localhost";

		initListeners();
		onTimeGet.run = () -> send({type: GetTime});
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
		final guestName:InputElement = cast ge("#guestname");
		guestName.onkeydown = (e:KeyboardEvent) -> {
			if (e.keyCode == 13) send({
				type: Login,
				login: {
					clientName: guestName.value
				}
			});
		}

		final chatLine:InputElement = cast ge("#chatline");
		chatLine.onkeydown = function(e:KeyboardEvent) {
			switch (e.keyCode) {
				case 13: // Enter
					send({
						type: Message,
						message: {
							clientName: "",
							text: chatLine.value
						}
					});
					personalHistory.push(chatLine.value);
					if (personalHistory.length > 50) personalHistory.shift();
					personalHistoryId = -1;
					chatLine.value = "";
				case 38: // Up
					personalHistoryId--;
					if (personalHistoryId == -2) {
						personalHistoryId = personalHistory.length - 1;
						if (personalHistoryId == -1) return;
					} else if (personalHistoryId == -1) personalHistoryId++;
					chatLine.value = personalHistory[personalHistoryId];
				case 40: // Down
					if (personalHistoryId == -1) return;
					personalHistoryId++;
					if (personalHistoryId > personalHistory.length - 1) {
						personalHistoryId = -1;
						chatLine.value = "";
						return;
					}
					chatLine.value = personalHistory[personalHistoryId];
			}
		}

		MobileView.init();

		final leaderBtn:InputElement = cast ge("#leader_btn");
		leaderBtn.onclick = (e) -> {
			if (personal == null) return;
			leaderBtn.classList.toggle('label-success');
			final name = personal.isLeader ? "" : personal.name;
			send({
				type: SetLeader,
				setLeader: {
					clientName: name
				}
			});
		}

		final showMediaUrl:ButtonElement = cast ge("#showmediaurl");
		showMediaUrl.onclick = (e:MouseEvent) -> {
			ge("#showmediaurl").classList.toggle("collapsed");
			ge("#showmediaurl").classList.toggle("active");
			ge("#addfromurl").classList.toggle("collapse");
		}
		ge("#queue_next").onclick = (e:MouseEvent) -> addVideoUrl();
		ge("#queue_end").onclick = (e:MouseEvent) -> addVideoUrl();
		ge("#mediaurl").onkeydown = function(e:KeyboardEvent) {
			if (e.keyCode == 13) addVideoUrl();
		}
	}

	public function isLeader():Bool {
		return personal != null && personal.isLeader;
	}

	function addVideoUrl():Void {
		final mediaUrl:InputElement = cast ge("#mediaurl");
		final url = mediaUrl.value;
		final name = personal == null ? "Unknown" : personal.name;
		getRemoteVideoDuration(mediaUrl.value, (duration:Float) -> {
			send({
				type: AddVideo,
				addVideo: {
					item: {
						url: url,
						title: Lang.get("rawVideo"),
						author: name,
						duration: duration
					}
				}
			});
		});
		mediaUrl.value = "";
	}

	function getRemoteVideoDuration(src:String, callback:(duration:Float)->Void):Void {
		final player:Element = ge("#ytapiplayer");
		final video = document.createVideoElement();
		video.src = src;
		video.onloadedmetadata = () -> {
			trace(video.duration);
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
				if (data.connected.isUnknownClient) {
					updateClients(data.connected.clients);
					ge("#guestlogin").style.display = "block";
					ge("#chatline").style.display = "none";
				} else {
					onLogin(data.connected.clients, data.connected.clientName);
				}
				final list = data.connected.videoList;
				if (list.length == 0) return;
				player.setVideo(list[0]);
				for (video in data.connected.videoList) {
					player.addVideoItem(video);
				}
			case Login:
				onLogin(data.login.clients, data.login.clientName);
			case LoginError:
				serverMessage(4, Lang.get("usernameError"));
			case Logout:
				updateClients(data.logout.clients);
				personal = null;
				ge("#guestlogin").style.display = "block";
				ge("#chatline").style.display = "none";
			case UpdateClients:
				updateClients(data.updateClients.clients);
				if (personal != null) personal = clients.getByName(personal.name);
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
				player.pause();
				player.setTime(data.pause.time);
			case Play:
				player.setTime(data.play.time);
				player.play();
			case GetTime:
				final newTime = data.getTime.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) < 2) return;
				player.setTime(newTime);
				if (!data.getTime.paused) player.play();
			case SetTime:
				final newTime = data.setTime.time;
				final time = player.getTime();
				if (Math.abs(time - newTime) < 2) return;
				player.setTime(newTime);
			case SetLeader:
				clients.setLeader(data.setLeader.clientName);
				updateUserList();
				if (personal == null) return;
				final leaderBtn:InputElement = cast ge("#leader_btn");
				if (personal.isLeader) leaderBtn.classList.add('label-success');
				else leaderBtn.classList.remove('label-success');
		}
	}

	function onLogin(data:Array<ClientData>, clientName:String):Void {
		updateClients(data);
		personal = clients.getByName(clientName);
		if (personal == null) return;
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

	final pageTitle = document.title;

	function updateUserList():Void {
		final userCount = ge("#usercount");
		userCount.innerHTML = clients.length + " " + Lang.get("online");
		document.title = '$pageTitle (${clients.length})';

		final list = new StringBuf();
		for (client in clients) {
			// final klass = client.isLeader ? "userlist_owner" : "userlist_item";
			final klass = "userlist_item";
			if (client.isLeader) list.add('<span class="glyphicon glyphicon-star-empty"></span>');
			list.add('<span class="$klass">${client.name}</span></br>');
		}
		final userlist = ge("#userlist");
		userlist.innerHTML = list.toString();
	}

	function addMessage(name:String, msg:String):Void {
		final msgBuf = ge("#messagebuffer");
		final userDiv = document.createDivElement();
		userDiv.className = 'chat-msg-$name';

		final tstamp = document.createSpanElement();
		tstamp.className = "timestamp";
		tstamp.innerHTML = "[" + new Date().toTimeString().split(" ")[0] + "] ";

		final nameDiv = document.createElement("strong");
		nameDiv.className = "username";
		nameDiv.innerHTML = name + ": ";

		final textDiv = document.createSpanElement();
		textDiv.innerHTML = msg;

		final isInChatEnd = msgBuf.scrollHeight - msgBuf.scrollTop == msgBuf.clientHeight;
		userDiv.appendChild(tstamp);
		userDiv.appendChild(nameDiv);
		userDiv.appendChild(textDiv);
		msgBuf.appendChild(userDiv);
		if (isInChatEnd) msgBuf.scrollTop = msgBuf.scrollHeight;
	}

	public static inline function ge(id:String):Element {
		return document.querySelector(id);
	}

}
