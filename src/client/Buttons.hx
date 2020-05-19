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

	static var split:Split;
	static var settings:ClientSettings;

	public static function init(main:Main):Void {
		settings = main.settings;
		if (settings.isSwapped) document.body.classList.add("swap");
		initSplit();
		setSplitSize(settings.playerSize, settings.chatSize);
		initChatInput(main);

		final passIcon = ge("#guestpass_icon");
		passIcon.onclick = e -> {
			final icon = passIcon.firstElementChild;
			final isOpen = icon.getAttribute("name") == "eye-off";
			final pass:InputElement = cast ge("#guestpass");
			if (isOpen) {
				pass.type = "password";
				icon.setAttribute("name", "eye");
			} else {
				pass.type = "text";
				icon.setAttribute("name", "eye-off");
			}
		}

		final smilesBtn = ge("#smilesbtn");
		smilesBtn.onclick = e -> {
			final smilesWrap = ge("#smileswrap");
			if (smilesWrap.children.length == 0) return;
			final isActive = smilesBtn.classList.toggle("active");
			if (isActive) smilesWrap.style.display = "grid";
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
			final icon = userlistToggle.firstElementChild;
			final isHidden = userlistToggle.classList.toggle("chevron-right");
			userlistToggle.classList.toggle("chevron-down");
			final style = ge("#userlist").style;
			if (isHidden) {
				style.display = "none";
				icon.setAttribute("name", "chevron-forward");
			}
			else {
				style.display = "block";
				icon.setAttribute("name", "chevron-down");
			}
			settings.isUserListHidden = isHidden;
			Settings.write(settings);
		}
		ge("#usercount").onclick = userlistToggle.onclick;
		if (settings.isUserListHidden) userlistToggle.onclick();

		final toggleSynch = ge("#togglesynch");
		toggleSynch.onclick = e -> {
			final icon = toggleSynch.firstElementChild;
			if (main.isSyncActive) {
				if (!window.confirm(Lang.get("toggleSynchConfirm"))) return;
				main.isSyncActive = false;
				icon.style.color = "rgba(238, 72, 67, 0.75)";
				icon.setAttribute("name", "pause");
			} else {
				main.isSyncActive = true;
				icon.style.color = "";
				icon.setAttribute("name", "play");
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
			icon.setAttribute("name", "checkmark");
			Timer.delay(() -> {
			icon.setAttribute("name", "link");
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

		final showOptions = ge("#showoptions");
		showOptions.onclick = e -> {
			final isActive = toggleGroup(showOptions);
			ge("#messagebuffer").style.display = isActive ? "none" : "block";
			ge("#chatbox").style.display = isActive ? "none" : "flex";
			ge("#userlisttoggle").style.display = isActive ? "none" : "inline-flex";
			ge("#optionsTitle").style.display = isActive ? "inline-flex" : "none";
		}

		final exitBtn = ge("#exitBtn");
		exitBtn.onclick = e -> {
			if (main.isUser()) main.send({type: Logout});
			else ge("#guestname").focus();
			toggleGroup(showOptions);
		}

		final swapLayoutBtn = ge("#swapLayoutBtn");
		swapLayoutBtn.onclick = e -> {
			settings.isSwapped = ge("body").classList.toggle("swap");
			final sizes = document.body.style.gridTemplateColumns.split(" ");
			sizes.reverse();
			document.body.style.gridTemplateColumns = sizes.join(" ");
			Settings.write(settings);
		}
	}

	static function showPlayerGroup(el:Element):Void {
		final groups:Array<Element> = cast document.querySelectorAll('[data-target]');
		for (group in groups) {
			if (el == group) continue;
			if (group.classList.contains("collapsed")) continue;
			toggleGroup(group);
		}
		toggleGroup(el);
	}

	static function toggleGroup(el:Element):Bool {
		el.classList.toggle("collapsed");
		ge(el.dataset.target).classList.toggle("collapse");
		return el.classList.toggle("active");
	}

	static function initSplit():Void {
		if (split != null) split.destroy();
		split = new Split({
			columnGutters: [{
				element: ge(".gutter"),
				track: 1,
			}],
			minSize: 200,
			snapOffset: 0,
			onDragEnd: saveSplitSize
		});
	}

	static function setSplitSize(playerSize:Float, chatSize:Float):Void {
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		final playerId = settings.isSwapped ? sizes.length - 1 : 0;
		final chatId = settings.isSwapped ? 0 : sizes.length - 1;
		sizes[playerId] = '${playerSize}fr';
		sizes[chatId] = '${chatSize}fr';
		document.body.style.gridTemplateColumns = sizes.join(" ");
	}

	static function	saveSplitSize():Void {
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		if (settings.isSwapped) sizes.reverse();
		settings.playerSize = Std.parseFloat(sizes[0]);
		settings.chatSize = Std.parseFloat(sizes[sizes.length - 1]);
		Settings.write(settings);
	}

	public static function initTextButtons(main:Main):Void {
		final synchThresholdBtn = ge("#synchThresholdBtn");
		synchThresholdBtn.onclick = e -> {
			var secs = settings.synchThreshold + 1;
			if (secs > 5) secs = 1;
			main.setSynchThreshold(secs);
			updateSynchThresholdBtn();
		}
		updateSynchThresholdBtn();

		final hotkeysBtn = ge("#hotkeysBtn");
		hotkeysBtn.onclick = e -> {
			settings.hotkeysEnabled = !settings.hotkeysEnabled;
			Settings.write(settings);
			updateHotkeysBtn();
		}
		updateHotkeysBtn();

		final removeBtn = ge("#removeVideoBtn");
		removeBtn.onclick = e -> {
			final has = main.toggleVideoElement();
			if (has || main.isListEmpty()) removeBtn.innerText = Lang.get("removeVideo");
			else removeBtn.innerText = Lang.get("addVideo");
		}
	}

	public static function initHotkeys(main:Main, player:Player):Void {
		ge("#mediarefresh").title += " (Alt-R)";
		ge("#voteskip").title += " (Alt-S)";
		ge("#getplaylist").title += " (Alt-C)";
		ge("#fullscreenbtn").title += " (Alt-F)";
		ge("#leader_btn").title += " (Alt-L)";
		window.onkeydown = function(e:KeyboardEvent) {
			if (!settings.hotkeysEnabled) return;
			final target:Element = cast e.target;
			if (target.isContentEditable) return;
			final tagName = target.tagName;
			if (tagName == "INPUT" || tagName == "TEXTAREA") return;
			final key:KeyCode = cast e.keyCode;
			if (key == Backspace) e.preventDefault();
			if (!e.altKey) return;
			switch (key) {
				case R: ge("#mediarefresh").onclick();
				case S: ge("#voteskip").onclick();
				case C: ge("#getplaylist").onclick();
				case F: ge("#fullscreenbtn").onclick();
				case L: ge("#leader_btn").onclick();
				case P:
					if (!main.isLeader()) {
						Timer.delay(() -> player.pause(), 500);
					}
					ge("#leader_btn").onclick();
				default: return;
			}
			e.preventDefault();
		}
	}

	static function updateSynchThresholdBtn():Void {
		final text = Lang.get("synchThreshold");
		final secs = settings.synchThreshold;
		ge("#synchThresholdBtn").innerText = '$text: ${secs}s';
	}

	static function updateHotkeysBtn():Void {
		final text = Lang.get("hotkeys");
		final state = settings.hotkeysEnabled ? Lang.get("on") : Lang.get("off");
		ge("#hotkeysBtn").innerText = '$text: $state';
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

		new InputWithHistory(cast ge("#chatline"), 50, value -> {
			main.send({
				type: Message,
				message: {
					clientName: "",
					text: value
				}
			});
			return true;
		});
	}

}
