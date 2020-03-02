package client;

import haxe.Timer;
import js.html.KeyboardEvent;
import js.html.InputElement;
import js.html.Element;
import client.Main.ge;
import js.Browser.window;
import js.Browser.document;
import js.html.Event;

class Buttons {

	static final personalHistory:Array<String> = [];
	static var personalHistoryId = -1;
	static var split:Split;

	public static function init(main:Main):Void {
		initChatInput(main);
		initNavBar(main);

		final smilesBtn = ge("#smilesbtn");
		smilesBtn.onclick = e -> {
			smilesBtn.classList.toggle("active");
			final smilesWrap = ge("#smileswrap");
			if (smilesBtn.classList.contains("active"))
				smilesWrap.style.display = "block";
			else smilesWrap.style.display = "none";
		}

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
				ge("#userlist").style.width = "90px";
			} else {
				split.setSizes([20, 80]);
				ge("#userlist").style.width = "80px";
			}
			extendPlayer.classList.toggle("active");
			window.dispatchEvent(new Event("resize"));
		}

		final mediaRefresh = ge("#mediarefresh");
		mediaRefresh.onclick = e -> {
			main.refreshPlayer();
		}
		final fullscreenBtn = ge("#fullscreenbtn");
		fullscreenBtn.onclick = e -> {
			final el = ge("#ytapiplayer");
			Utils.toggleFullScreen(el);
		}
		final getPlaylist = ge("#getplaylist");
		getPlaylist.onclick = e -> {
			final text = main.getPlaylistLinks().join(",");
			Utils.copyToClipboard(text);
			final icon = getPlaylist.firstElementChild;
			icon.classList.remove("glyphicon-link");
			icon.classList.add("glyphicon-ok");
			Timer.delay(() -> {
				icon.classList.add("glyphicon-link");
				icon.classList.remove("glyphicon-ok");
			}, 2000);
		}
		final clearPlaylist = ge("#clearplaylist");
		clearPlaylist.onclick = e -> {
			if (!window.confirm(Lang.get("clearPlaylistConfirm"))) return;
			main.send({type: ClearPlaylist});
		}
		final shufflePlaylist = ge("#shuffleplaylist");
		shufflePlaylist.onclick = e -> {
			if (!window.confirm(Lang.get("shufflePlaylistConfirm"))) return;
			main.send({type: ShufflePlaylist});
		}

		final showMediaUrl = ge("#showmediaurl");
		showMediaUrl.onclick = e -> {
			ge("#showmediaurl").classList.toggle("collapsed");
			ge("#showmediaurl").classList.toggle("active");
			ge("#addfromurl").classList.toggle("collapse");
		}

		window.onresize = onVideoResize;
		initSplit();
	}

	static function initSplit(swapped = false):Void {
		if (split != null) split.destroy();
		final divs = ["#chatwrap", "#videowrap"];
		final sizes = [40, 60];
		if (swapped) {
			divs.reverse();
			sizes.reverse();
		}
		split = new Split(divs, {
			sizes: sizes,
			onDragEnd: () -> {
				window.dispatchEvent(new Event("resize"));
			},
			minSize: 185,
			snapOffset: 0
		});
		window.dispatchEvent(new Event("resize"));
	}

	static function onVideoResize():Void {
		final player = ge("#ytapiplayer");
		final height = player.offsetHeight - ge("#chatline").offsetHeight;
		ge("#messagebuffer").style.height = '${height}px';
		ge("#userlist").style.height = '${height}px';
	}

	static function initNavBar(main:Main):Void {
		final classes:Array<Element> = cast document.querySelectorAll(".dropdown-toggle");
		for (klass in classes) {
			klass.onclick = e -> {
				klass.classList.toggle("focus");
				hideMenus();
				final menu = klass.parentElement.querySelector(".dropdown-menu");
				if (menu.style.display == "") menu.style.display = "block";
				else menu.style.display = "";
			}
			klass.onmouseover = klass.onclick;
		}
		final classes:Array<Element> = cast document.querySelectorAll(".dropdown");
		for (klass in classes) {
			klass.onmouseleave = e -> {
				final toggle:Element = cast klass.querySelector(".dropdown-toggle");
				toggle.classList.remove("focus");
				toggle.blur();
				final menu = klass.querySelector(".dropdown-menu");
				menu.style.display = "";
			}
		}

		final exitBtn = ge("#exitBtn");
		exitBtn.onclick = e -> {
			if (main.isUser()) main.send({type: Logout});
			else ge("#guestname").focus();
			exitBtn.blur();
			hideMenus();
		}
		final swapLayoutBtn = ge("#swapLayoutBtn");
		swapLayoutBtn.onclick = e -> {
			final p = ge("#main");
			p.insertBefore(p.children[2], p.children[0]);
			p.insertBefore(p.children[2], p.children[1]);
			final p = ge("#controlsrow");
			p.insertBefore(p.children[1], p.children[0]);
			final p = ge("#playlistrow");
			p.insertBefore(p.children[1], p.children[0]);
			final swapped = ge("#main").firstElementChild == ge("#videowrap");
			initSplit(swapped);
			swapLayoutBtn.blur();
			hideMenus();
		}
		final removeBtn = ge("#removeVideoBtn");
		removeBtn.onclick = e -> {
			final has = main.toggleVideoElement();
			if (has) removeBtn.innerText = Lang.get("removeVideo");
			else removeBtn.innerText = Lang.get("addVideo");
			removeBtn.blur();
			hideMenus();
		}
	}

	static function hideMenus():Void {
		final menus:Array<Element> = cast document.querySelectorAll(".dropdown-menu");
		for (menu in menus) menu.style.display = "";
	}

	static function initChatInput(main:Main):Void {
		final guestName:InputElement = cast ge("#guestname");
		guestName.onkeydown = e -> {
			if (e.keyCode == 13) main.guestLogin(guestName.value);
		}

		final guestPass:InputElement = cast ge("#guestpass");
		guestPass.onkeydown = e -> {
			if (e.keyCode == 13) main.userLogin(guestName.value, guestPass.value);
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
