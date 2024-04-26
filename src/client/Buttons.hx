package client;

import client.Main.ge;
import haxe.Timer;
import js.Browser.document;
import js.Browser.window;
import js.html.Element;
import js.html.ImageElement;
import js.html.InputElement;
import js.html.KeyboardEvent;
import js.html.VisualViewport;

using StringTools;

class Buttons {
	static inline var CHAT_MIN_SIZE = 200;
	static var split:Split;
	static var settings:ClientSettings;

	public static function init(main:Main):Void {
		settings = main.settings;
		if (settings.isSwapped) swapPlayerAndChat();
		initSplit();
		setSplitSize(settings.chatSize);
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
			final wrap = ge("#smiles-wrap");
			final list = ge("#smiles-list");
			if (list.children.length == 0) return;
			final isActive = smilesBtn.classList.toggle("active");
			if (isActive) {
				wrap.style.display = "block";
				wrap.style.height = outerHeight(list) + "px";
			} else {
				wrap.style.height = "0";
				wrap.addEventListener("transitionend", e -> {
					wrap.style.display = "none";
				}, {once: true});
			}
			if (list.firstElementChild.dataset.src == null) return;
			for (child in list.children) {
				(cast child : ImageElement).src = child.dataset.src;
				child.removeAttribute("data-src");
			}
		}

		final scrollToChatEndBtn = ge("#scroll-to-chat-end");
		function scrollToChatEndBtnAnim():Void {
			if (scrollToChatEndBtn.style.opacity == "0") return;
			scrollToChatEndBtn.style.opacity = "0";
			scrollToChatEndBtn.addEventListener("transitionend", e -> {
				scrollToChatEndBtn.style.display = "none";
			}, {once: true});
		}
		scrollToChatEndBtn.onclick = e -> {
			main.scrollChatToEnd();
			scrollToChatEndBtnAnim();
		}
		// hide scroll button when chat is scrolled to the end
		final msgBuf = ge("#messagebuffer");
		msgBuf.onscroll = e -> {
			if (msgBuf.offsetHeight + msgBuf.scrollTop < msgBuf.scrollHeight - 1) return;
			scrollToChatEndBtnAnim();
		}

		ge("#clearchatbtn").onclick = e -> {
			if (main.isAdmin()) main.send({type: ClearChat});
		}
		final userList = ge("#userlist");
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

		final userlistToggle = ge("#userlisttoggle");
		userlistToggle.onclick = e -> {
			final icon = userlistToggle.firstElementChild;
			final isHidden = icon.getAttribute("name") == "chevron-forward";
			final wrap = ge("#userlist-wrap");
			final style = ge("#userlist").style;
			if (isHidden) {
				icon.setAttribute("name", "chevron-down");
				style.display = "block";
				final list = wrap.firstElementChild;
				wrap.style.height = outerHeight(list) + "px";
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
		ge("#usercount").onclick = userlistToggle.onclick;
		if (settings.isUserListHidden) userlistToggle.onclick();
		else {
			final wrap = ge("#userlist-wrap");
			final list = wrap.firstElementChild;
			wrap.style.height = outerHeight(list) + "px";
		}
		// enable animation after page loads
		Timer.delay(() -> {
			ge("#userlist-wrap").style.transition = "200ms";
		}, 0);

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
			if ((Utils.isTouch() || main.isVerbose()) && !Utils.hasFullscreen()) {
				Utils.requestFullscreen(document.documentElement);
			} else {
				Utils.requestFullscreen(ge("#ytapiplayer"));
			}
		}
		initPageFullscreen();
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
			if (!main.hasPermission(LockPlaylistPerm)) return;
			if (main.isPlaylistOpen) {
				if (!window.confirm(Lang.get("lockPlaylistConfirm"))) return;
			}
			main.send({
				type: TogglePlaylistLock
			});
		}

		final showMediaUrl = ge("#showmediaurl");
		showMediaUrl.onclick = e -> {
			final isOpen = showPlayerGroup(showMediaUrl);
			if (isOpen) Timer.delay(() -> {
				ge("#addfromurl").scrollIntoView();
				ge("#mediaurl").focus();
			}, 100);
		}

		final showCustomEmbed = ge("#showcustomembed");
		showCustomEmbed.onclick = e -> {
			final isOpen = showPlayerGroup(showCustomEmbed);
			if (isOpen) Timer.delay(() -> {
				ge("#customembed").scrollIntoView();
				ge("#customembed-title").focus();
			}, 100);
		}

		final mediaUrl:InputElement = cast ge("#mediaurl");
		mediaUrl.oninput = () -> {
			final value = mediaUrl.value;
			final isRawSingleVideo = value != "" && main.isRawPlayerLink(value)
				&& main.isSingleVideoLink(value);
			ge("#mediatitleblock").style.display = isRawSingleVideo ? "" : "none";
			ge("#subsurlblock").style.display = isRawSingleVideo ? "" : "none";
			final panel = ge("#addfromurl");
			final oldH = panel.style.height; // save for animation
			panel.style.height = ""; // to calculate height from content
			final newH = outerHeight(panel) + "px";
			panel.style.height = oldH;
			Timer.delay(() -> panel.style.height = newH, 0);
		}
		mediaUrl.onfocus = mediaUrl.oninput;

		ge("#insert_template").onclick = e -> {
			mediaUrl.value = main.getTemplateUrl();
			mediaUrl.focus();
		}

		final showOptions = ge("#showoptions");
		showOptions.onclick = e -> {
			final isActive = toggleGroup(showOptions);
			ge("#optionsPanel").style.opacity = isActive ? "1" : "0";
			Timer.delay(() -> {
				if (showOptions.classList.contains("active") != isActive) return;
				ge("#optionsPanel").classList.toggle("collapse", !isActive);
			}, isActive ? 0 : 200);
		}

		final exitBtn = ge("#exitBtn");
		exitBtn.onclick = e -> {
			if (main.isUser()) main.send({type: Logout});
			else ge("#guestname").focus();
			toggleGroup(showOptions);
		}

		final swapLayoutBtn = ge("#swapLayoutBtn");
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
		final target = ge(el.dataset.target);
		final isClosed = target.classList.toggle("collapse");
		if (isClosed) {
			target.style.height = "0";
		} else {
			final list = target.firstElementChild;
			if (target.style.height == "") target.style.height = "0";
			target.style.height = outerHeight(list) + "px";
		}
		return el.classList.toggle("active");
	}

	static function outerHeight(el:Element):Float {
		final style = window.getComputedStyle(el);
		return (el.getBoundingClientRect().height
			+ Std.parseFloat(style.marginTop)
			+ Std.parseFloat(style.marginBottom));
	}

	static function swapPlayerAndChat():Void {
		settings.isSwapped = ge("body").classList.toggle("swap");
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		sizes.reverse();
		document.body.style.gridTemplateColumns = sizes.join(" ");
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

	static function setSplitSize(chatSize:Float):Void {
		if (chatSize < CHAT_MIN_SIZE) return;
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		final chatId = settings.isSwapped ? 0 : sizes.length - 1;
		sizes[chatId] = '${chatSize}px';
		document.body.style.gridTemplateColumns = sizes.join(" ");
	}

	static function saveSplitSize():Void {
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		if (settings.isSwapped) sizes.reverse();
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

		final removeBtn = ge("#removePlayerBtn");
		removeBtn.onclick = e -> {
			final isActive = main.toggleVideoElement();
			if (isActive) {
				removeBtn.innerText = Lang.get("removePlayer");
			} else {
				removeBtn.innerText = Lang.get("restorePlayer");
			}
		}
		final setVideoUrlBtn = ge("#setVideoUrlBtn");
		setVideoUrlBtn.onclick = e -> {
			final src = window.prompt(Lang.get("setVideoUrlPrompt"));
			if (src.trim() == "") { // reset to default url
				main.refreshPlayer();
				return;
			}
			JsApi.setVideoSrc(src);
		}
		final selectLocalVideoBtn = ge("#selectLocalVideoBtn");
		selectLocalVideoBtn.onclick = e -> {
			Utils.browseFileUrl((url:String, name:String) -> {
				JsApi.setVideoSrc(url);
			});
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
			if (isElementEditable(target)) return;
			final key:KeyCode = cast e.keyCode;
			if (key == Backspace) e.preventDefault();
			if (!e.altKey) return;
			switch (key) {
				case R:
					ge("#mediarefresh").onclick();
				case S:
					ge("#voteskip").onclick();
				case C:
					ge("#getplaylist").onclick();
				case F:
					ge("#fullscreenbtn").onclick();
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
			if (e.keyCode == KeyCode.Return) {
				main.guestLogin(guestName.value);
				if (Utils.isTouch()) guestName.blur();
			}
		}

		final guestPass:InputElement = cast ge("#guestpass");
		guestPass.onkeydown = e -> {
			if (e.keyCode == KeyCode.Return) {
				main.userLogin(guestName.value, guestPass.value);
				guestPass.value = "";
				if (Utils.isTouch()) guestPass.blur();
			}
		}

		if (Utils.isIOS()) {
			document.ontouchmove = e -> {
				e.preventDefault();
			}
			document.body.style.height = "-webkit-fill-available";
			ge("#chat").style.height = "-webkit-fill-available";
		}
		final chatline:InputElement = cast ge("#chatline");
		chatline.onfocus = e -> {
			if (Utils.isIOS()) {
				final startY = window.scrollY;
				Timer.delay(() -> {
					window.scrollBy(0, -(window.scrollY - startY));
					ge("#video").scrollTop = 0;
					main.scrollChatToEnd();
					if (getVisualViewport() == null) { // ios < 13
						ge("#chat").style.height = '${window.innerHeight}px';
					}
				}, 100);
			} else if (Utils.isTouch()) main.scrollChatToEnd();
		}
		if (Utils.isIOS() && getVisualViewport() != null) {
			final viewport = getVisualViewport();
			viewport.addEventListener("resize", e -> {
				ge("#chat").style.height = '${window.innerHeight}px';
			});
		}
		chatline.onblur = e -> {
			if (Utils.isIOS() && getVisualViewport() == null) { // ios < 13
				ge("#chat").style.height = "-webkit-fill-available";
			}
		}
		new InputWithHistory(chatline, 50, value -> {
			if (main.handleCommands(value)) return true;
			main.send({
				type: Message,
				message: {
					clientName: "",
					text: value
				}
			});
			if (Utils.isTouch()) chatline.blur();
			return true;
		});
	}

	static inline function getVisualViewport():Null<VisualViewport> {
		return (window : Dynamic).visualViewport;
	}

	static function initPageFullscreen():Void {
		document.onfullscreenchange = e -> {
			final el = document.documentElement;
			if (Utils.hasFullscreen()) {
				if (e.target == el) el.classList.add("mobile-view");
			} else el.classList.remove("mobile-view");
		}
	}

	public static function updatePausedBy(name:String):Void {
		
		// update the field
		final list = new StringBuf();

		list.add('<div class="pausedby_item">');
		list.add('<ion-icon name="pause"></ion-icon>');
		list.add('<span>'+ name + '</span></div>');

		final pausedlist = ge("#pausedby");
		pausedlist.innerHTML = list.toString();
		
		//check if it is hidden and do the animation
		final wrap = ge("#pausedby-wrap");
		final pb = ge("#pausedby");
		final isHidden = pb.style.display == "none";
		
		//if(isHidden && name != null){
		pb.style.display = "block";
		final list = wrap.firstElementChild;
		wrap.style.height = "3rem"; //outerHeight(list) + "px";
		wrap.style.marginBottom = ".5rem";
		// }
		// else{
		// 	pb.style.display = "none";
		// 	wrap.style.height = "0";
		// 	wrap.style.marginBottom = "0rem";
		// }
	}
}
