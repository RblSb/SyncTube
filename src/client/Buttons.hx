package client;

import js.html.ImageElement;
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
	static var settings:ClientSettings;

	public static function init(main:Main):Void {
		settings = main.settings;
		window.onresize = onVideoResize;
		initSplit();
		initChatInput(main);
		initNavBar(main);

		final passIcon = ge("#guestpass_icon");
		passIcon.onclick = e -> {
			final isOpen = passIcon.classList.toggle("glyphicon-eye-open");
			passIcon.classList.toggle("glyphicon-eye-close");
			final pass:InputElement = cast ge("#guestpass");
			if (isOpen) pass.type = "password";
			else pass.type = "text";
		}

		final smilesBtn = ge("#smilesbtn");
		smilesBtn.onclick = e -> {
			final smilesWrap = ge("#smileswrap");
			if (smilesWrap.children.length == 0) return;
			final isActive = smilesBtn.classList.toggle("active");
			if (isActive) smilesWrap.style.display = "block";
			else smilesWrap.style.display = "none";
			if (smilesWrap.firstElementChild.dataset.src == null) return;
			for (child in smilesWrap.children) {
				(cast child : ImageElement).src = child.dataset.src;
				child.removeAttribute("data-src");
			}
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
			final isHidden = userlistToggle.classList.toggle("glyphicon-chevron-right");
			userlistToggle.classList.toggle("glyphicon-chevron-down");
			final style = ge("#userlist").style;
			if (isHidden) style.display = "none";
			else style.display = "block";
			settings.isUserListHidden = isHidden;
			Settings.write(settings);
		}
		ge("#usercount").onclick = userlistToggle.onclick;
		if (settings.isUserListHidden) userlistToggle.onclick();

		final extendPlayer = ge("#extendplayer");
		extendPlayer.onclick = e -> {
			final isExtended = extendPlayer.classList.toggle("active");
			final sizes = isExtended ? [20, 80] : [40, 60];
			ge("#userlist").style.width = isExtended ? "80px" : "90px";
			if (settings.isSwapped) sizes.reverse();
			split.setSizes(sizes);
			settings.isExtendedPlayer = isExtended;
			writeSplitSize();
			window.dispatchEvent(new Event("resize"));
		}
		if (settings.isExtendedPlayer) extendPlayer.onclick();

		final toggleSynch = ge("#togglesynch");
		toggleSynch.onclick = e -> {
			final icon = toggleSynch.firstElementChild;
			if (main.isSyncActive) {
				if (!window.confirm(Lang.get("toggleSynchConfirm"))) return;
				main.isSyncActive = false;
				icon.style.color = "rgba(238, 72, 67, 0.75)";
				icon.classList.add("glyphicon-pause");
				icon.classList.remove("glyphicon-play");
			} else {
				main.isSyncActive = true;
				icon.style.color = "";
				icon.classList.add("glyphicon-play");
				icon.classList.remove("glyphicon-pause");
				main.send({type: UpdatePlaylist});
			}
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
		final lockPlaylist = ge("#lockplaylist");
		lockPlaylist.onclick = e -> {
			if (main.isAdmin()) main.send({type: TogglePlaylistLock});
		}

		final showMediaUrl = ge("#showmediaurl");
		showMediaUrl.onclick = e -> showPlayerGroup(showMediaUrl);

		final showCustomEmbed = ge("#showcustomembed");
		showCustomEmbed.onclick = e -> showPlayerGroup(showCustomEmbed);

		ge("#insert_template").onclick = e -> {
			final input:InputElement = cast ge("#mediaurl");
			input.value = main.getTemplateUrl();
			input.focus();
		}
	}

	static function showPlayerGroup(el:Element):Void {
		final groups:Array<Element> = cast document.querySelectorAll('[data-target]');
		for (group in groups) {
			if (el == group) continue;
			group.classList.add("collapsed");
			group.classList.remove("active");
			ge(group.dataset.target).classList.add("collapse");
		}
		el.classList.toggle("collapsed");
		el.classList.toggle("active");
		ge(el.dataset.target).classList.toggle("collapse");
	}

	static function initSplit():Void {
		if (split != null) split.destroy();
		final divs = ["#chatwrap", "#videowrap"];
		final sizes = [settings.chatSize, settings.playerSize];
		if (settings.isSwapped) {
			divs.reverse();
			sizes.reverse();
		}
		split = new Split(divs, {
			sizes: sizes,
			onDragEnd: () -> {
				window.dispatchEvent(new Event("resize"));
				writeSplitSize();
			},
			minSize: 185,
			snapOffset: 0
		});
		window.dispatchEvent(new Event("resize"));
	}

	static function writeSplitSize():Void {
		final sizes = split.getSizes();
		if (settings.isSwapped) sizes.reverse();
		settings.chatSize = sizes[0];
		settings.playerSize = sizes[1];
		Settings.write(settings);
	}

	static function onVideoResize():Void {
		final player = ge("#ytapiplayer");
		final height = player.offsetHeight - ge("#chatline").offsetHeight;
		ge("#messagebuffer").style.height = '${height}px';
		ge("#userlist").style.height = '${height}px';
	}

	static function onClick(el:Element, func:Any->Void):Void {
		final isTouch = untyped __js__("'ontouchstart' in window");
		if (!isTouch) el.onclick = func;
		else el.ontouchend = func;
	}

	static function initNavBar(main:Main):Void {
		final toggleMenu = ge("#toggleMenu");
		final onclick = e -> {
			ge("#nav-collapsible").classList.toggle("in");
		}
		onClick(toggleMenu, onclick);

		final classes:Array<Element> = cast document.querySelectorAll(".dropdown-toggle");
		for (klass in classes) {
			klass.onclick = e -> {
				final isActive = klass.classList.toggle("focus");
				hideMenus();
				final menu = klass.parentElement.querySelector(".dropdown-menu");
				if (isActive) menu.style.display = "block";
				else menu.style.display = "none";
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
		final synchThresholdBtn = ge("#synchThresholdBtn");
		synchThresholdBtn.onclick = e -> {
			var secs = main.synchThreshold + 1;
			if (secs > 5) secs = 1;
			main.setSynchThreshold(secs);
			updateSynchThresholdBtn(main);
			synchThresholdBtn.blur();
		}
		final secs = main.synchThreshold;
		synchThresholdBtn.innerText += ': ${secs}s';

		final swapLayoutBtn = ge("#swapLayoutBtn");
		swapLayoutBtn.onclick = e -> {
			final p = ge("#main");
			p.insertBefore(p.children[2], p.children[0]);
			p.insertBefore(p.children[2], p.children[1]);
			final p = ge("#controlsrow");
			p.insertBefore(p.children[1], p.children[0]);
			final p = ge("#playlistrow");
			p.insertBefore(p.children[1], p.children[0]);
			settings.isSwapped = ge("#main").firstElementChild == ge("#videowrap");
			Settings.write(settings);
			initSplit();
			swapLayoutBtn.blur();
			hideMenus();
		}
		if (settings.isSwapped) swapLayoutBtn.onclick();
		final removeBtn = ge("#removeVideoBtn");
		removeBtn.onclick = e -> {
			final has = main.toggleVideoElement();
			if (has || main.isListEmpty()) removeBtn.innerText = Lang.get("removeVideo");
			else removeBtn.innerText = Lang.get("addVideo");
			removeBtn.blur();
			hideMenus();
		}
	}

	static function hideMenus():Void {
		final menus:Array<Element> = cast document.querySelectorAll(".dropdown-menu");
		for (menu in menus) menu.style.display = "";
	}

	static function updateSynchThresholdBtn(main:Main):Void {
		final text = Lang.get("synchThreshold");
		final secs = main.synchThreshold;
		ge("#synchThresholdBtn").innerText = '$text: ${secs}s';
	}

	static function initChatInput(main:Main):Void {
		final guestName:InputElement = cast ge("#guestname");
		guestName.onkeydown = e -> {
			if (e.keyCode == 13) main.guestLogin(guestName.value);
		}

		final guestPass:InputElement = cast ge("#guestpass");
		guestPass.onkeydown = e -> {
			if (e.keyCode == 13) {
				main.userLogin(guestName.value, guestPass.value);
				guestPass.value = "";
			}
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
