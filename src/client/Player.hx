package client;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.ge;
import client.players.Iframe;
import client.players.Raw;
import client.players.Streamable;
import client.players.Vk;
import client.players.Youtube;
import haxe.Http;
import haxe.Json;
import js.html.Audio;
import js.html.Element;
import js.html.InputElement;

class Player {
	final main:Main;
	final youtube:Youtube;
	final players:Array<IPlayer>;
	final iframePlayer:IPlayer;
	final rawPlayer:IPlayer;
	final videoList = new VideoList();
	final videoItemsEl = ge("#queue");
	final playerEl = ge("#ytapiplayer");
	var player:Null<IPlayer>;
	var isLoaded = false;
	var skipSetTime = false;
	var skipSetRate = false;
	var streamable:Streamable;

	final voiceOverInput:InputElement = cast ge("#voiceoverurl");
	var audioTrack:Null<Audio>;
	var isAudioTrackLoaded = false;
	var needsVolumeReset = false;
	final voiceOverVolume = 0.3;

	public function new(main:Main):Void {
		this.main = main;
		youtube = new Youtube(main, this);
		streamable = new Streamable(main, this);
		players = [
			youtube,
			new Vk(main, this),
			streamable,
		];
		iframePlayer = new Iframe(main, this);
		rawPlayer = new Raw(main, this);
		initItemButtons();

		final resizeObserver = Utils.createResizeObserver(entries -> {
			if (isLoaded) return;
			Buttons.onViewportResize();
		});
		if (resizeObserver != null) {
			resizeObserver.observe(playerEl);
		} else {
			final timer = new haxe.Timer(50);
			timer.run = () -> {
				if (isLoaded) return;
				Buttons.onViewportResize();
			}
		}
	}

	function initItemButtons():Void {
		final queue = ge("#queue");
		queue.onclick = e -> {
			final btn:Element = cast e.target;
			final item = btn.parentElement.parentElement;
			final i = Utils.getIndex(item.parentElement, item);
			if (btn.classList.contains("qbtn-play")) {
				main.send({
					type: PlayItem,
					playItem: {
						pos: i
					}
				});
			}
			if (btn.classList.contains("qbtn-next")) {
				main.send({
					type: SetNextItem,
					setNextItem: {
						pos: i
					}
				});
			}
			if (btn.classList.contains("qbtn-tmp")) {
				main.send({
					type: ToggleItemType,
					toggleItemType: {
						pos: i
					}
				});
			}
			if (btn.classList.contains("qbtn-delete")) {
				main.removeVideoItem(item.querySelector(".qe_title").getAttribute("href"));
			}
		}
	}

	public function setNextItem(pos:Int):Void {
		videoList.setNextItem(pos);

		final next = videoItemsEl.children[pos];
		videoItemsEl.removeChild(next);
		Utils.insertAtIndex(videoItemsEl, next, videoList.pos + 1);
	}

	public function toggleItemType(pos:Int):Void {
		videoList.toggleItemType(pos);
		final el = videoItemsEl.children[pos];
		setItemElementType(el, videoList.getItem(pos).isTemp);
	}

	public function getCurrentItem():Null<VideoItem> {
		return videoList.currentItem;
	}

	function setPlayer(newPlayer:IPlayer):Void {
		if (player != newPlayer) {
			if (player != null) {
				JsApi.fireVideoRemoveEvents(videoList.currentItem);
				player.removeVideo();
				removeExternalAudioTrack();
			}
			main.blinkTabWithTitle("*Video*");
		}
		player = newPlayer;
	}

	public function getVideoData(req:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		var player = players.find(player -> player.isSupportedLink(req.url));
		player ??= rawPlayer;
		player.getVideoData(req, data -> {
			data.playerType ??= player.getPlayerType();
			final voiceOverTrack = voiceOverInput.value.trim();
			voiceOverInput.value = "";
			data.voiceOverTrack ??= voiceOverTrack;
			callback(data);
		});
	}

	public function getLinkPlayerType(url:String):PlayerType {
		final player = players.find(player -> player.isSupportedLink(url));
		if (player == null) return rawPlayer.getPlayerType();
		return player.getPlayerType();
	}

	public function isSingleVideoUrl(url:String):Bool {
		if (youtube.isSupportedLink(url)) {
			if (youtube.isPlaylistUrl(url)) return false;
		}
		if (~/, ?(https?)/g.match(url)) return false;
		if (main.urlMask.match(url)) return false;
		return true;
	}

	public function getIframeData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		iframePlayer.getVideoData(data, data -> {
			data.playerType = IframeType;
			callback(data);
		});
	}

	public function setVideo(i:Int):Void {
		if (!main.isSyncActive) return;
		final item = videoList.getItem(i);
		setSupportedPlayer(item.url, item.playerType);

		removeActiveLabel(videoList.pos);
		videoList.setPos(i);
		addActiveLabel(videoList.pos);

		isLoaded = false;
		if (main.isVideoEnabled) {
			player.loadVideo(item);
			setExternalAudioTrack(item);
		} else {
			onCanBePlayed();
		}
		JsApi.fireVideoChangeEvents(item);
		ge("#currenttitle").textContent = item.title;
	}

	function setExternalAudioTrack(item:VideoItem):Void {
		removeExternalAudioTrack();
		final voiceOverTrack = item.voiceOverTrack ?? return;
		if (voiceOverTrack.length == 0) return;
		audioTrack = new Audio(voiceOverTrack);
		if (!main.isAutoplayAllowed()) {
			audioTrack.muted = true;
		}
		inline function cleanAudioEvents() {
			audioTrack.oncanplay = null;
			audioTrack.onerror = null;
		}
		audioTrack.oncanplay = () -> {
			cleanAudioEvents();
			isAudioTrackLoaded = true;
		}
		audioTrack.onerror = e -> {
			trace(e);
			cleanAudioEvents();
			isAudioTrackLoaded = false;
			audioTrack = null;
			setVolume(1);
		}
	}

	function removeExternalAudioTrack():Void {
		isAudioTrackLoaded = false;
		needsVolumeReset = false;
		if (audioTrack == null) return;

		audioTrack?.pause();
		audioTrack.src = null;
		audioTrack = null;
		needsVolumeReset = true;
	}

	function setSupportedPlayer(url:String, playerType:PlayerType):Void {
		final currentPlayer = players.find(p -> p.isSupportedLink(url));
		if (currentPlayer != null) setPlayer(currentPlayer);
		else if (playerType == IframeType) setPlayer(iframePlayer);
		else setPlayer(rawPlayer);
	}

	public function changeVideoSrc(url:String):Void {
		if (!main.isVideoEnabled) return;
		final item:VideoItem = videoList.currentItem ?? return;
		setSupportedPlayer(url, item.playerType);
		player.loadVideo(item.withUrl(url));
	}

	public function removeVideo():Void {
		JsApi.fireVideoRemoveEvents(videoList.currentItem);
		player.removeVideo();
		ge("#currenttitle").textContent = Lang.get("nothingPlaying");
		setPauseIndicator(false);
	}

	public function setPauseIndicator(isPause:Bool):Void {
		if (!main.isSyncActive) return;
		final state = isPause ? "pause" : "play";
		final el = ge("#pause-indicator");
		el.setAttribute("name", state);

		final el2 = ge("#pause-indicator-portrait");
		el2.setAttribute("name", "pause");
		var isVisible = isPause || main.hasLeader();
		el2.style.display = isVisible ? "" : "none";
	}

	public function onCanBePlayed():Void {
		if (!isLoaded) main.send({type: VideoLoaded});
		isLoaded = true;
		Buttons.onViewportResize();
	}

	public function onPlay():Void {
		audioTrack?.play();

		if (!main.isLeader()) {
			// paused and no leader - instant pause
			if (main.lastState.paused) pause();
			return;
		}
		main.send({
			type: Play,
			play: {
				time: getTime()
			}
		});
		final hasAutoPause = main.hasLeaderOnPauseRequest() && videoList.length > 0;
		if (hasAutoPause) {
			// do not remove leader if user cannot request it back
			if (main.hasPermission(RequestLeaderPerm)) main.toggleLeader();
		}
	}

	public function onPause():Void {
		audioTrack?.pause();

		final item = videoList.currentItem ?? return;
		// do not send pause if video is ended
		if (getTime() >= item.duration - 0.01) return;
		var hasAutoPause = main.hasLeaderOnPauseRequest()
			&& videoList.length > 0
			&& getTime() > 1
			&& isLoaded;
		// do not set leader on pause if user tried to play server-paused video
		if (main.showingServerPause) hasAutoPause = false;
		// set leader and pause
		if (hasAutoPause && !main.hasLeader()) {
			JsApi.once(SetLeader, event -> {
				final name = event.setLeader.clientName;
				if (name != main.getName()) return;
				main.send({
					type: Pause,
					pause: {
						time: getTime()
					}
				});
				player.pause();
			});
			main.toggleLeader();
			return;
		}
		if (!main.isLeader()) {
			// no pause and no permission - instant play
			if (!main.lastState.paused) play();
			return;
		}
		// we are leader, so just send pause
		main.send({
			type: Pause,
			pause: {
				time: getTime()
			}
		});
	}

	public function onSetTime():Void {
		if (audioTrack != null) {
			audioTrack.currentTime = getTime();
		}

		if (skipSetTime) {
			skipSetTime = false;
			return;
		}
		if (!main.isLeader()) return;
		main.send({
			type: SetTime,
			setTime: {
				time: getTime()
			}
		});
	}

	public function onRateChange():Void {
		if (audioTrack != null) {
			audioTrack.playbackRate = getPlaybackRate();
		}
		if (skipSetRate) {
			skipSetRate = false;
			return;
		}
		if (!main.isLeader()) return;
		main.send({
			type: SetRate,
			setRate: {
				rate: getPlaybackRate()
			}
		});
	}

	public function addVideoItem(item:VideoItem, atEnd:Bool):Void {
		final url = item.url.htmlEscape(true);
		final duration = item.playerType == IframeType ? "" : duration(item.duration);
		final itemEl = Utils.nodeFromString(
			'<li class="queue_entry info" title="${Lang.get("addedBy")}: ${item.author}">
				<header>
					<span class="qe_time">$duration</span>
					<h4><a class="qe_title" href="$url" target="_blank">${item.title.htmlEscape()}</a></h4>
				</header>
				<span class="controls">
					<button class="qbtn-play" title="${Lang.get("play")}"><ion-icon name="play"></ion-icon></button>
					<button class="qbtn-next" title="${Lang.get("setNext")}"><ion-icon name="arrow-up"></ion-icon></button>
					<button class="qbtn-tmp"><ion-icon></ion-icon></button>
					<button class="qbtn-delete" title="${Lang.get("delete")}"><ion-icon name="close"></ion-icon></button>
				</span>
			</li>'
		);
		videoList.addItem(item, atEnd);
		setItemElementType(itemEl, item.isTemp);
		if (atEnd) videoItemsEl.appendChild(itemEl);
		else Utils.insertAtIndex(videoItemsEl, itemEl, videoList.pos + 1);
		updateCounters();
	}

	function setItemElementType(item:Element, isTemp:Bool):Void {
		final btn = item.querySelector(".qbtn-tmp");
		btn.title = isTemp ? Lang.get("makePermanent") : Lang.get("makeTemporary");
		final iconType = isTemp ? "lock-open" : "lock-closed";
		btn.firstElementChild.setAttribute("name", iconType);
		item.classList.toggle("queue_temp", isTemp);
	}

	public function removeItem(url:String):Void {
		removeElementItem(url);
		var index = videoList.findIndex(item -> item.url == url);
		if (index == -1) return;

		final isCurrent = videoList.currentItem.url == url;
		videoList.removeItem(index);
		updateCounters();

		if (isCurrent && videoList.length > 0) {
			setVideo(videoList.pos);
		}
	}

	function removeElementItem(url:String):Void {
		for (child in videoItemsEl.children) {
			if (child.querySelector(".qe_title").getAttribute("href") == url) {
				videoItemsEl.removeChild(child);
				break;
			}
		}
	}

	public function skipItem(url:String):Void {
		final pos = videoList.findIndex(item -> item.url == url);
		if (pos == -1) return;
		removeActiveLabel(videoList.pos);
		videoList.setPos(pos);
		if (videoList.currentItem.isTemp) removeElementItem(url);
		videoList.skipItem();
		updateCounters();
		if (videoList.length == 0) return;
		setVideo(videoList.pos);
	}

	function addActiveLabel(pos:Int):Void {
		final childs = videoItemsEl.children;
		if (childs[videoList.pos] != null) {
			childs[videoList.pos].classList.add("queue_active");
		}
	}

	function removeActiveLabel(pos:Int):Void {
		final childs = videoItemsEl.children;
		if (childs[videoList.pos] != null) {
			childs[videoList.pos].classList.remove("queue_active");
		}
	}

	function updateCounters():Void {
		ge("#plcount").textContent = '${videoList.length} ${Lang.get("videos")}';
		ge("#pllength").textContent = totalDuration();
	}

	public function getItems():Array<VideoItem> {
		return videoList.getItems();
	}

	public function setItems(list:Array<VideoItem>, ?pos:Int):Void {
		final currentUrl = videoList.pos >= videoList.length ? "" : videoList.currentItem.url;
		clearItems();
		if (list.length == 0) return;
		for (video in list) {
			addVideoItem(video, true);
		}
		if (pos != null) videoList.setPos(pos);
		if (currentUrl != videoList.currentItem.url) setVideo(videoList.pos);
		else addActiveLabel(videoList.pos);
	}

	public function clearItems():Void {
		videoList.clear();
		videoItemsEl.textContent = "";
		updateCounters();
	}

	public function refresh():Void {
		if (videoList.length == 0) return;
		final time = getTime();
		removeVideo();
		setVideo(videoList.pos);
		// restore server time for leader with next GetTime
		if (main.isLeader()) {
			setTime(time);
			main.forceSyncNextTick = true;
		}
	}

	function duration(time:Float):String {
		final h = Std.int(time / 60 / 60);
		final m = Std.int(time / 60) - h * 60;
		final s = Std.int(time % 60);
		var time = '$m:';
		if (m < 10) time = '0$time';
		if (h > 0) time = '$h:$time';
		if (s < 10) time = time + "0";
		time += s;
		return time;
	}

	function totalDuration():String {
		var time = 0.0;
		for (item in videoList.getItems()) {
			if (item.playerType == IframeType) continue;
			time += item.duration;
		}
		return duration(time);
	}

	public function isListEmpty():Bool {
		return videoList.length == 0;
	}

	public function itemsLength():Int {
		return videoList.length;
	}

	public function getItemPos():Int {
		return videoList.pos;
	}

	public function hasVideo():Bool {
		return playerEl.children.length != 0;
	}

	public function getDuration():Float {
		if (videoList.pos >= videoList.length) return 0;
		return videoList.currentItem.duration;
	}

	public function isVideoLoaded():Bool {
		if (player == null) return false;
		return player.isVideoLoaded();
	}

	public function play():Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		player.play();
		if (needsVolumeReset) setVolume(1);

		if (audioTrack != null) {
			setVolume(0.3);
			audioTrack?.play();
		}
	}

	public function pause():Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		player.pause();

		audioTrack?.pause();
	}

	public function getTime():Float {
		if (player == null) return 0;
		if (!player.isVideoLoaded()) return 0;
		return player.getTime();
	}

	public function setTime(time:Float, isLocal = true):Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		skipSetTime = isLocal;
		player.setTime(time);

		if (audioTrack != null) audioTrack.currentTime = time;
	}

	public function getPlaybackRate():Float {
		if (player == null) return 1;
		if (!player.isVideoLoaded()) return 1;
		return player.getPlaybackRate();
	}

	public function setPlaybackRate(rate:Float, isLocal = true):Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		skipSetRate = isLocal;
		player.setPlaybackRate(rate);

		if (audioTrack != null) audioTrack.playbackRate = rate;
	}

	public function skipAd():Void {
		final item = videoList.currentItem ?? return;
		if (!youtube.isSupportedLink(item.url)) return;
		final id = youtube.extractVideoId(item.url);
		final url = 'https://sponsor.ajay.app/api/skipSegments?videoID=$id';
		final http = new Http(url);
		http.onData = text -> {
			final json:Array<{segment:Array<Float>}> = try {
				Json.parse(text);
			} catch (e) {
				return;
			}
			for (block in json) {
				final start = block.segment[0];
				final end = block.segment[1];
				final time = getTime();
				if (time > start - 1 && time < end) {
					main.send({
						type: Rewind,
						rewind: {
							time: end - time - 1
						}
					});
				}
			}
		}
		http.onError = msg -> trace(msg);
		http.request();
	}

	public function isPaused():Bool {
		if (player == null) return true;
		if (!player.isVideoLoaded()) return true;
		return player.isPaused();
	}

	public function getVolume():Float {
		if (player == null) return 1;
		if (!player.isVideoLoaded()) return 1;
		return player.getVolume();
	}

	public function setVolume(volume:Float):Void {
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		player.setVolume(volume);
	}

	public function unmute():Void {
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		player.unmute();
		if (audioTrack != null) audioTrack.muted = false;
		if (audioTrack == null && almostEq(getVolume(), voiceOverVolume, 0.01)) {
			setVolume(1);
		}
	}

	function almostEq(a:Float, b:Float, diff:Float):Bool {
		return a > b - diff && a < b + diff;
	}
}
