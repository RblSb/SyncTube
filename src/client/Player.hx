package client;

import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.ge;
import client.players.Iframe;
import client.players.Raw;
import client.players.Youtube;
import js.html.Element;

using Lambda;
using StringTools;

class Player {
	final main:Main;
	final players:Array<IPlayer>;
	final iframePlayer:IPlayer;
	final rawPlayer:IPlayer;
	final videoList = new VideoList();
	final videoItemsEl = ge("#queue");
	final playerEl:Element = ge("#ytapiplayer");
	var player:Null<IPlayer>;
	var isLoaded = false;
	var skipSetTime = false;
	var skipSetRate = false;

	public function new(main:Main):Void {
		this.main = main;
		players = [
			new Youtube(main, this)
		];
		iframePlayer = new Iframe(main, this);
		rawPlayer = new Raw(main, this);
		initItemButtons();
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

	function setPlayer(newPlayer:IPlayer):Void {
		if (player != newPlayer) {
			if (player != null) {
				JsApi.fireVideoRemoveEvents(videoList.getCurrentItem());
				player.removeVideo();
			}
			main.blinkTabWithTitle("*Video*");
		}
		player = newPlayer;
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		var player = players.find(player -> player.isSupportedLink(data.url));
		if (player == null) player = rawPlayer;
		player.getVideoData(data, callback);
	}

	public function isRawPlayerLink(url:String):Bool {
		return !players.exists(player -> player.isSupportedLink(url));
	}

	public function getIframeData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		iframePlayer.getVideoData(data, callback);
	}

	public function setVideo(i:Int):Void {
		if (!main.isSyncActive) return;
		final item = videoList.getItem(i);
		var currentPlayer = players.find(p -> p.isSupportedLink(item.url));
		if (currentPlayer != null) setPlayer(currentPlayer);
		else if (item.isIframe) setPlayer(iframePlayer);
		else setPlayer(rawPlayer);

		removeActiveLabel(videoList.pos);
		videoList.setPos(i);
		addActiveLabel(videoList.pos);

		isLoaded = false;
		player.loadVideo(item);
		JsApi.fireVideoChangeEvents(item);
		ge("#currenttitle").textContent = item.title;
	}

	public function changeVideoSrc(src:String):Void {
		if (player == null) return;
		final item = videoList.getCurrentItem();
		if (item == null) return;
		player.loadVideo({
			url: src,
			title: item.title,
			author: item.author,
			duration: item.duration,
			subs: item.subs,
			isTemp: item.isTemp,
			isIframe: item.isIframe
		});
	}

	public function removeVideo():Void {
		JsApi.fireVideoRemoveEvents(videoList.getCurrentItem());
		player.removeVideo();
		ge("#currenttitle").textContent = Lang.get("nothingPlaying");
		setPauseIndicator(true);
	}

	public function setPauseIndicator(flag:Bool):Void {
		if (!main.isSyncActive) return;
		final state = flag ? "play" : "pause";
		final el = ge("#pause-indicator");
		if (el.getAttribute("name") == state) return;
		el.setAttribute("name", state);
	}

	public function onCanBePlayed():Void {
		if (!isLoaded) main.send({type: VideoLoaded});
		isLoaded = true;
	}

	public function onPlay():Void {
		if (!main.isLeader()) return;
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
		final hasAutoPause = main.hasLeaderOnPauseRequest() && videoList.length > 0
			&& getTime() > 1;
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
		if (!main.isLeader()) return;
		main.send({
			type: Pause,
			pause: {
				time: getTime()
			}
		});
	}

	public function onSetTime():Void {
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
		final duration = item.isIframe ? "" : duration(item.duration);
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
		if (isTemp) item.classList.add("queue_temp");
		else item.classList.remove("queue_temp");
	}

	public function removeItem(url:String):Void {
		removeElementItem(url);
		var index = videoList.findIndex(item -> item.url == url);
		if (index == -1) return;

		final isCurrent = videoList.getCurrentItem().url == url;
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
		if (videoList.getCurrentItem().isTemp) removeElementItem(url);
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
		final currentUrl = videoList.pos >= videoList.length ? "" : videoList.getCurrentItem()
			.url;
		clearItems();
		if (list.length == 0) return;
		for (video in list) {
			addVideoItem(video, true);
		}
		if (pos != null) videoList.setPos(pos);
		if (currentUrl != videoList.getCurrentItem().url) setVideo(videoList.pos);
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
			if (item.isIframe) continue;
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
		return videoList.getCurrentItem().duration;
	}

	public function isVideoLoaded():Bool {
		return player.isVideoLoaded();
	}

	public function play():Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		player.play();
	}

	public function pause():Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		if (!player.isVideoLoaded()) return;
		player.pause();
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
	}
}
