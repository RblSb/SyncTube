package client;

import js.html.KeyboardEvent;
import js.html.InputElement;
import js.html.ButtonElement;
import js.html.Element;
import client.Main.ge;
import js.Browser.window;
import js.html.Event;

class Buttons {

	static final personalHistory:Array<String> = [];
	static var personalHistoryId = -1;
	static var split:Split;

	public static function init(main:Main):Void {
		initChatInput(main);

		final smilesBtn = ge("#smilesbtn");
		smilesBtn.onclick = e -> {
			smilesBtn.classList.toggle("active");
			final smilesWrap = ge("#smileswrap");
			if (smilesBtn.classList.contains("active"))
				smilesWrap.style.display = "block";
			else smilesWrap.style.display = "none";
		}

		ge("#clearchatbtn").style.display = "inline-block";
		ge("#clearchatbtn").onclick = e -> {
			if (main.isAdmin()) main.send({type: ClearChat});
		}
		final userList = ge("#userlist");
		userList.onclick = e -> {
			if (!main.isAdmin()) return;
			var el:Element = cast e.target;
			if (userList == el) return;
			if (!el.classList.contains("userlist_item"))
				el = el.parentElement;
			var name = "";
			if (el.children.length == 1) {
				name = el.lastElementChild.innerText;
			}
			main.send({
				type: SetLeader,
				setLeader: {
					clientName: name
				}
			});
		}

		split = new Split(["#chatwrap", "#videowrap"], {
			sizes: [40, 60],
			onDragEnd: () -> {
				window.dispatchEvent(new Event("resize"));
			},
			minSize: 185,
			snapOffset: 0
		});

		final userlistToggle = ge("#userlisttoggle");
		userlistToggle.onclick = e -> {
			final style = ge("#userlist").style;
			if (style.display == "none") {
				userlistToggle.classList.add("glyphicon-chevron-down");
				userlistToggle.classList.remove("glyphicon-chevron-right");
				style.display = "block";
			} else {
				userlistToggle.classList.add("glyphicon-chevron-right");
				userlistToggle.classList.remove("glyphicon-chevron-down");
				style.display = "none";
			}
		}
		ge("#usercount").onclick = userlistToggle.onclick;

		final extendPlayer = ge("#extendplayer");
		extendPlayer.onclick = e -> {
			if (extendPlayer.classList.contains("active")) {
				split.setSizes([40, 60]);
				ge('#userlist').style.width = "90px";
			} else {
				split.setSizes([20, 80]);
				ge('#userlist').style.width = "80px";
			}
			extendPlayer.classList.toggle("active");
			window.dispatchEvent(new Event('resize'));
		}

		final showMediaUrl:ButtonElement = cast ge("#showmediaurl");
		showMediaUrl.onclick = e -> {
			ge("#showmediaurl").classList.toggle("collapsed");
			ge("#showmediaurl").classList.toggle("active");
			ge("#addfromurl").classList.toggle("collapse");
		}

		window.onresize = onVideoResize;
		window.dispatchEvent(new Event("resize"));
	}

	static function onVideoResize():Void {
		final player = ge("#ytapiplayer");
		final height = player.offsetHeight - ge("#chatline").offsetHeight;
		ge("#messagebuffer").style.height = '${height}px';
		ge("#userlist").style.height = '${height}px';
	}


	static function initChatInput(main:Main):Void {
		final guestName:InputElement = cast ge("#guestname");
		guestName.onkeydown = e -> {
			if (guestName.value.length == 0) return;
			if (e.keyCode == 13) main.send({
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
					if (chatLine.value.length == 0) return;
					main.send({
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
	}

}
