package client;

import client.Main.getEl;
import haxe.Timer;
import js.Browser.document;
import js.Browser.window;
import js.html.Element;
import js.html.Event;
import js.html.ImageElement;
import js.html.InputElement;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.TransitionEvent;
import js.html.VisualViewport;

class Buttons {
	static var split:Split;
	static var settings:ClientSettings;

	public static function init(main:Main):Void {
		settings = main.settings;
		if (settings.isSwapped) swapPlayerAndChat();

		split?.destroy();
		split = new Split(settings);
		split.setSize(settings.chatSize);

		initInputs(main);

		for (item in settings.checkboxes) {
			if (item.checked == null) continue;
			final checkbox = (getEl('#${item.id}') : InputElement) ?? continue;
			checkbox.checked = item.checked;
		}

		final passIcon = getEl("#guestpass_icon");
		passIcon.onclick = e -> {
			final icon = passIcon.firstElementChild;
			final isOpen = icon.getAttribute("name") == "eye-off";
			final pass:InputElement = getEl("#guestpass");
			if (isOpen) {
				pass.type = "password";
				icon.setAttribute("name", "eye");
			} else {
				pass.type = "text";
				icon.setAttribute("name", "eye-off");
			}
		}

		final smilesBtn = getEl("#smilesbtn");
		smilesBtn.onclick = e -> {
			final wrap = getEl("#smiles-wrap");
			final list = getEl("#smiles-list");
			if (list.children.length == 0) return;
			final isActive = smilesBtn.classList.toggle("active");
			if (isActive) {
				wrap.style.display = "";
				wrap.style.height = Utils.outerHeight(list) + "px";
			} else {
				wrap.style.height = "0";
				function onTransitionEnd(e:TransitionEvent):Void {
					if (e.propertyName != "height") return;
					wrap.style.display = "none";
					wrap.removeEventListener("transitionend", onTransitionEnd);
				}
				wrap.addEventListener("transitionend", onTransitionEnd);
			}
			if (list.firstElementChild.dataset.src == null) return;
			for (child in list.children) {
				(cast child : ImageElement).src = child.dataset.src;
				child.removeAttribute("data-src");
			}
		}

		final scrollToChatEndBtn = getEl("#scroll-to-chat-end");
		scrollToChatEndBtn.onclick = e -> {
			main.scrollChatToEnd();
			main.hideScrollToChatEndBtn();
		}
		// hide scroll button when chat is scrolled to the end
		final msgBuf = getEl("#messagebuffer");
		msgBuf.onscroll = e -> {
			if (!main.isInChatEnd(1)) return;
			main.hideScrollToChatEndBtn();
		}

		getEl("#clearchatbtn").onclick = e -> {
			if (main.isAdmin()) main.send({type: ClearChat});
		}
		final userList = getEl("#userlist");
		userList.onclick = e -> {
			if (!main.isAdmin()) return;
			var el:Element = cast e.target;
			if (userList == el) return;
			if (!el.classList.contains("userlist_item")) {
				el = el.parentElement;
			}
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

		final userlistToggle = getEl("#userlisttoggle");
		userlistToggle.onclick = e -> {
			final icon = userlistToggle.firstElementChild;
			final isHidden = icon.getAttribute("name") == "chevron-forward";
			final wrap = getEl("#userlist-wrap");
			final style = getEl("#userlist").style;
			if (isHidden) {
				icon.setAttribute("name", "chevron-down");
				style.display = "";
				wrap.style.height = "15vh";
				wrap.style.marginBottom = "1rem";
			} else {
				icon.setAttribute("name", "chevron-forward");
				style.display = "none";
				wrap.style.height = "0";
				wrap.style.marginBottom = "0rem";
			}
			settings.isUserListHidden = !isHidden;
			Settings.write(settings);
		}
		getEl("#usercount").onclick = userlistToggle.onclick;
		if (settings.isUserListHidden) userlistToggle.onclick();
		else {
			final wrap = getEl("#userlist-wrap");
			wrap.style.height = "15vh";
		}
		// enable animation after page loads
		Timer.delay(() -> {
			getEl("#userlist-wrap").style.transition = "200ms";
		}, 0);

		final playlistMenuBtn = getEl("#playlist-menu-btn");
		final playlistMenuDropdown = getEl("#playlist-menu-dropdown");

		inline function closePlaylistMenu() {
			playlistMenuDropdown.style.display = "none";
			playlistMenuBtn.classList.remove("active");
		}

		final toggleSynch = getEl("#togglesynch");
		toggleSynch.onclick = e -> {
			closePlaylistMenu();
			final icon = toggleSynch.firstElementChild;
			if (main.isSyncActive) {
				if (!window.confirm(Lang.get("toggleSynchConfirm"))) return;
				main.isSyncActive = false;
				icon.style.color = "rgba(238, 72, 67, 0.75)";
				playlistMenuBtn.classList.add("danger");
			} else {
				main.isSyncActive = true;
				icon.style.color = "";
				playlistMenuBtn.classList.remove("danger");
				main.send({type: UpdatePlaylist});
			}
			updateToggleSynchBtn(main);
		}
		final mediaRefresh = getEl("#mediarefresh");
		mediaRefresh.onclick = e -> {
			main.refreshPlayer();
		}
		final fullscreenBtn = getEl("#fullscreenbtn");
		fullscreenBtn.onclick = e -> {
			Utils.toggleFullscreen(getEl("#ytapiplayer"));
		}
		final chatBtn = getEl("#fullscreen-chat-btn");
		chatBtn.onclick = e -> {
			e.stopPropagation();
			e.preventDefault();
			clearUnreadChatMessages();

			if (settings.pageFullscreen) {
				Utils.switchToPageFullscreen();
			} else {
				Utils.cancelFullscreen();
			}
		}
		initPageFullscreen();
		final getPlaylist = getEl("#getplaylist");
		getPlaylist.onclick = e -> {
			final text = main.getPlaylistLinks().join(",");
			Utils.copyToClipboard(text);
			final icon = getPlaylist.firstElementChild;
			icon.setAttribute("name", "checkmark");
			Timer.delay(() -> {
				icon.setAttribute("name", "link");
			}, 2000);
		}

		playlistMenuBtn.onclick = e -> {
			e.stopPropagation();
			final isOpen = playlistMenuDropdown.style.display != "none";
			if (isOpen) {
				closePlaylistMenu();
			} else {
				main.hasSeenSkipVote = true;
				playlistMenuDropdown.style.display = "";
				playlistMenuBtn.classList.add("active");
				getEl("#playlist-menu-indicator").style.display = "none";
			}
		}

		document.addEventListener("click", e -> {
			final target:Element = cast e.target;
			if (!playlistMenuBtn.contains(target) && !playlistMenuDropdown.contains(target)) {
				closePlaylistMenu();
			}
		});

		final voteSkip = getEl("#voteskip");
		voteSkip.addEventListener("click", () -> closePlaylistMenu());

		final clearPlaylist = getEl("#clearplaylist");
		clearPlaylist.onclick = e -> {
			closePlaylistMenu();
			if (!window.confirm(Lang.get("clearPlaylistConfirm"))) return;
			main.send({type: ClearPlaylist});
		}
		final shufflePlaylist = getEl("#shuffleplaylist");
		shufflePlaylist.onclick = e -> {
			closePlaylistMenu();
			if (!window.confirm(Lang.get("shufflePlaylistConfirm"))) return;
			main.send({type: ShufflePlaylist});
		}

		final lockPlaylist = getEl("#lockplaylist");
		lockPlaylist.onclick = e -> {
			if (!main.hasPermission(LockPlaylistPerm)) return;
			if (main.isPlaylistOpen) {
				if (!window.confirm(Lang.get("lockPlaylistConfirm"))) return;
			}
			main.send({
				type: TogglePlaylistLock
			});
		}

		final showMediaUrl = getEl("#showmediaurl");
		showMediaUrl.onclick = e -> {
			closePlaylistMenu();
			final isOpen = showPlayerGroup(showMediaUrl);
			if (isOpen) Timer.delay(() -> {
				getEl("#addfromurl").scrollIntoView();
				getEl("#mediaurl").focus();
			}, 100);
		}

		final showCustomEmbed = getEl("#showcustomembed");
		showCustomEmbed.onclick = e -> {
			closePlaylistMenu();
			final isOpen = showPlayerGroup(showCustomEmbed);
			if (isOpen) Timer.delay(() -> {
				getEl("#customembed").scrollIntoView();
				getEl("#customembed-title").focus();
			}, 100);
		}

		final mediaUrl:InputElement = getEl("#mediaurl");
		final checkboxCache:InputElement = getEl("#cache-on-server");
		mediaUrl.oninput = () -> {
			final url = mediaUrl.value;
			final playerType = main.getLinkPlayerType(url);
			final isSingle = main.isSingleVideoUrl(url);
			final isSingleRawVideo = url != "" && playerType == RawType && isSingle;
			getEl("#mediatitleblock").style.display = isSingleRawVideo ? "" : "none";
			getEl("#subsurlblock").style.display = isSingleRawVideo ? "" : "none";
			getEl("#voiceoverblock").style.display = (url.length > 0 && isSingle) ? "" : "none";

			final isExternal = main.isExternalVideoUrl(url);
			final showCache = isSingle && isExternal
				&& main.playersCacheSupport.contains(playerType);
			checkboxCache.parentElement.style.display = showCache ? "" : "none";
			checkboxCache.checked = settings.checkedCache.contains(playerType);

			final panel = getEl("#addfromurl");
			final oldH = panel.style.height; // save for animation
			panel.style.height = ""; // to calculate height from content
			final newH = Utils.outerHeight(panel) + "px";
			panel.style.height = oldH;
			Timer.delay(() -> panel.style.height = newH, 0);
		}
		mediaUrl.onfocus = mediaUrl.oninput;

		checkboxCache.addEventListener("change", () -> {
			final url = mediaUrl.value;
			final playerType = main.getLinkPlayerType(url);
			final checked = checkboxCache.checked;

			settings.checkedCache.remove(playerType);
			if (checked) settings.checkedCache.push(playerType);
			Settings.write(settings);
		});

		getEl("#insert_template").onclick = e -> {
			mediaUrl.value = main.getTemplateUrl();
			mediaUrl.focus();
		}

		getEl("#mediaurl-upload").onclick = e -> {
			Utils.browseJsFile(file -> {
				final uploader = new FileUploader(main);
				uploader.uploadFile(file);
			});
		}

		final showOptions = getEl("#showoptions");
		showOptions.onclick = e -> {
			final isActive = toggleGroup(showOptions);
			getEl("#optionsPanel").style.opacity = isActive ? "1" : "0";
			Timer.delay(() -> {
				if (showOptions.classList.contains("active") != isActive) return;
				getEl("#optionsPanel").classList.toggle("collapse", !isActive);
			}, isActive ? 0 : 200);
		}

		final exitBtn = getEl("#exitBtn");
		exitBtn.onclick = e -> {
			showOptions.onclick();
			if (main.isUser()) main.send({type: Logout});
			else getEl("#guestname").focus();
		}

		final swapLayoutBtn = getEl("#swapLayoutBtn");
		swapLayoutBtn.onclick = e -> {
			swapPlayerAndChat();
			Settings.write(settings);
		}
	}

	static function showPlayerGroup(el:Element):Bool {
		final groups:Array<Element> = cast document.querySelectorAll('[data-target]');
		for (group in groups) {
			if (el == group) continue;
			if (group.classList.contains("collapsed")) continue;
			toggleGroup(group);
		}
		return toggleGroup(el);
	}

	static function toggleGroup(el:Element):Bool {
		el.classList.toggle("collapsed");
		final target = getEl(el.dataset.target);
		final isClosed = target.classList.toggle("collapse");
		if (isClosed) {
			target.style.height = "0";
		} else {
			final list = target.firstElementChild;
			if (target.style.height == "") target.style.height = "0";
			Timer.delay(() -> {
				target.style.height = Utils.outerHeight(list) + "px";
			}, 0);
		}
		return el.classList.toggle("active");
	}

	static function swapPlayerAndChat():Void {
		settings.isSwapped = getEl("body").classList.toggle("swap");
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		sizes.reverse();
		document.body.style.gridTemplateColumns = sizes.join(" ");
	}

	public static function initTextButtons(main:Main):Void {
		final synchThresholdBtn = getEl("#synchThresholdBtn");
		synchThresholdBtn.onclick = e -> {
			var secs = settings.synchThreshold + 1;
			if (secs > 5) secs = 1;
			main.setSynchThreshold(secs);
			updateSynchThresholdBtn();
		}
		updateSynchThresholdBtn();

		final hotkeysBtn = getEl("#hotkeysBtn");
		hotkeysBtn.onclick = e -> {
			settings.hotkeysEnabled = !settings.hotkeysEnabled;
			Settings.write(settings);
			updateHotkeysBtn();
		}
		updateHotkeysBtn();

		final pageFullscreenBtn = getEl("#pageFullscreenBtn");
		pageFullscreenBtn.onclick = e -> {
			settings.pageFullscreen = !settings.pageFullscreen;
			Settings.write(settings);
			updatePageFullscreenBtn();

			if (settings.pageFullscreen) {
				Utils.switchToPageFullscreen();
			} else {
				Utils.cancelFullscreen();
			}
		}
		updatePageFullscreenBtn();

		final fullscreenActionBtn = getEl("#fullscreenActionBtn");
		if (fullscreenActionBtn != null) {
			fullscreenActionBtn.onclick = e -> {
				settings.fullscreenAction = !settings.fullscreenAction;
				Settings.write(settings);
				updateFullscreenActionBtn();
			}
			updateFullscreenActionBtn();
		}

		document.body.addEventListener("click", e -> {
			if (!settings.pageFullscreen) return;
			if (Utils.hasFullscreen()) return;
			final target:Element = cast e.target;
			if (target != null
				&& target.closest("button, input, a, textarea, select, #optionsPanel, #chatline, #userlist, .queue_sortable, .nav") != null)
				return;
			Utils.requestFullscreen(document.documentElement);
		});

		final removeBtn = getEl("#removePlayerBtn");
		removeBtn.onclick = e -> {
			final isActive = main.toggleVideoElement();
			if (isActive) {
				removeBtn.innerText = Lang.get("removePlayer");
			} else {
				removeBtn.innerText = Lang.get("restorePlayer");
			}
		}
		final setVideoUrlBtn = getEl("#setVideoUrlBtn");
		setVideoUrlBtn.onclick = e -> {
			final src = window.prompt(Lang.get("setVideoUrlPrompt"));
			if (src.trim() == "") { // reset to default url
				main.refreshPlayer();
				return;
			}
			JsApi.setVideoSrc(src);
		}
		final selectLocalVideoBtn = getEl("#selectLocalVideoBtn");
		selectLocalVideoBtn.onclick = e -> {
			Utils.browseFileUrl((url, name) -> {
				JsApi.setVideoSrc(url);
			});
		}
		updateToggleSynchBtn(main);
	}

	public static function initHotkeys(main:Main, player:Player):Void {
		getEl("#mediarefresh").title += " (Alt-R)";
		getEl("#voteskip").title += " (Alt-S)";
		getEl("#getplaylist").title += " (Alt-C)";
		getEl("#fullscreenbtn").title += " (Alt-F)";
		getEl("#leader_btn").title += " (Alt-L)";
		window.onkeydown = (e:KeyboardEvent) -> {
			if (!settings.hotkeysEnabled) return;
			final target:Element = cast e.target;
			if (isElementEditable(target)) return;
			final key:KeyCode = cast e.keyCode;
			if (key == Backspace) e.preventDefault();
			if (!e.altKey) return;
			switch (key) {
				case R:
					getEl("#mediarefresh").onclick();
				case U:
					getEl("#togglesynch").onclick();
				case S:
					getEl("#voteskip").onclick();
				case C:
					getEl("#getplaylist").onclick();
				case F:
					getEl("#fullscreenbtn").onclick();
				case L:
					main.toggleLeader();
				case P:
					main.toggleLeaderAndPause();
				default:
					return;
			}
			e.preventDefault();
		}
	}

	static function isElementEditable(target:Element):Bool {
		if (target == null) return false;
		if (target.isContentEditable) return true;
		final tagName = target.tagName;
		if (tagName == "INPUT" || tagName == "TEXTAREA") return true;
		return false;
	}

	static function updateSynchThresholdBtn():Void {
		final text = Lang.get("synchThreshold");
		final secs = settings.synchThreshold;
		getEl("#synchThresholdBtn").innerText = '$text: ${secs}s';
	}

	static function updateHotkeysBtn():Void {
		final btn = getEl("#hotkeysBtn");
		var switchEl = btn.querySelector(".toggle-switch");
		if (switchEl == null) {
			final text = Lang.get("hotkeys");
			btn.innerHTML = '<span>$text</span><div class="toggle-switch"></div>';
			switchEl = btn.querySelector(".toggle-switch");
		}

		switchEl.classList.toggle("on", settings.hotkeysEnabled);
		document.body.classList.toggle("hotkeys-disabled", !settings.hotkeysEnabled);
	}

	static function updatePageFullscreenBtn():Void {
		final btn = getEl("#pageFullscreenBtn");
		var switchEl = btn.querySelector(".toggle-switch");
		if (switchEl == null) {
			final text = Lang.get("pageFullscreen");
			btn.innerHTML = '<span>$text</span><div class="toggle-switch"></div>';
			switchEl = btn.querySelector(".toggle-switch");
		}
		switchEl.classList.toggle("on", settings.pageFullscreen);
	}

	static function updateFullscreenActionBtn():Void {
		final btn = getEl("#fullscreenActionBtn");
		var switchEl = btn.querySelector(".toggle-switch");
		if (switchEl == null) {
			final text = Lang.get(Utils.isTouch() ? "fullscreenActionTouch" : "fullscreenActionDesktop");
			btn.innerHTML = '<span>$text</span><div class="toggle-switch"></div>';
			switchEl = btn.querySelector(".toggle-switch");
		}
		switchEl.classList.toggle("on", settings.fullscreenAction);
	}

	public static function updateToggleSynchBtn(main:Main):Void {
		final toggleSynch = getEl("#togglesynch");
		final span = toggleSynch.querySelector("span");
		final textKey = main.isSyncActive ? "disableVideoSync" : "enableVideoSync";
		final text = Lang.get(textKey);
		toggleSynch.title = '$text (Alt-U)';
		if (span != null) {
			span.innerHTML = '$text <span class="hotkey-hint">(Alt-U)</span>';
		}
	}

	static function initInputs(main:Main):Void {
		final guestName:InputElement = getEl("#guestname");
		guestName.onkeydown = e -> {
			if (e.keyCode == KeyCode.Return) {
				main.guestLogin(guestName.value);
				if (Utils.isTouch()) guestName.blur();
			}
		}

		final guestPass:InputElement = getEl("#guestpass");
		guestPass.onkeydown = e -> {
			if (e.keyCode == KeyCode.Return) {
				main.userLogin(guestName.value, guestPass.value);
				guestPass.value = "";
				if (Utils.isTouch()) guestPass.blur();
			}
		}

		final viewport = getVisualViewport();
		if (viewport != null) {
			viewport.addEventListener("resize", e -> onViewportResize());
			onViewportResize();
		}

		final checkboxes:Array<InputElement> = [
			getEl("#add-temp"),
		];
		for (checkbox in checkboxes) {
			checkbox.addEventListener("change", () -> {
				final checked = checkbox.checked;
				final item = settings.checkboxes.find(item -> item.id == checkbox.id);
				settings.checkboxes.remove(item);
				settings.checkboxes.push({id: checkbox.id, checked: checked});
				Settings.write(settings);
			});
		}
	}

	public static function onViewportResize():Void {
		final viewport = getVisualViewport() ?? return;
		final isPortrait = window.innerHeight > window.innerWidth;
		final playerH = getEl("#ytapiplayer").offsetHeight;
		var h = viewport.height - playerH;
		if (!isPortrait) h = viewport.height;
		getEl("#chat").style.height = '${h}px';
	}

	static inline function getVisualViewport():Null<VisualViewport> {
		return (window : Dynamic).visualViewport;
	}

	public static var hasUnreadChatMessages:Bool = false;

	public static function onNewChatMessage():Void {
		hasUnreadChatMessages = true;
		updateFullscreenChatBtn();
	}

	public static function clearUnreadChatMessages():Void {
		hasUnreadChatMessages = false;
		updateFullscreenChatBtn();
	}

	public static function updateFullscreenChatBtn():Void {
		final chatBtn = getEl("#fullscreen-chat-btn");
		final isFs = Utils.hasFullscreen();
		if (isFs && hasUnreadChatMessages) {
			chatBtn.classList.add("has-unread");
		} else {
			chatBtn.classList.remove("has-unread");
		}
	}

	static function initPageFullscreen():Void {
		document.onfullscreenchange = e -> {
			clearUnreadChatMessages();
			updateFullscreenChatBtn();
		}
	}
}
