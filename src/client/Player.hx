package client;

import js.html.Element;
import client.Main.ge;
import client.players.Raw;
import client.players.Youtube;
import client.players.Iframe;
import Types.VideoDataRequest;
import Types.VideoData;
import Types.VideoItem;
using StringTools;
using Lambda;

class Player {

	final main:Main;
	final players:Array<IPlayer>;
	final iframePlayer:IPlayer;
	final rawPlayer:IPlayer;
	final items = new VideoList();
	final videoItemsEl = ge("#queue");
	final playerEl:Element = ge("#ytapiplayer");
	var player:Null<IPlayer>;
	var itemPos = 0;
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
					type: PlayItem, playItem: {
						pos: i
					}
				});
			}
			if (btn.classList.contains("qbtn-next")) {
				main.send({
					type: SetNextItem, setNextItem: {
						pos: i
					}
				});
			}
			if (btn.classList.contains("qbtn-tmp")) {
				main.send({
					type: ToggleItemType, toggleItemType: {
						pos: i
					}
				});
			}
			if (btn.classList.contains("qbtn-delete")) {
				main.send({
					type: RemoveVideo, removeVideo: {
						url: item.querySelector(".qe_title").getAttribute("href")
					}
				});
			}
		}
	}

	public function setNextItem(pos:Int):Void {
		itemPos = items.setNextItem(pos, itemPos);

		final next = videoItemsEl.children[pos];
		videoItemsEl.removeChild(next);
		Utils.insertAtIndex(videoItemsEl, next, itemPos + 1);
	}

	public function toggleItemType(pos:Int):Void {
		items.toggleItemType(pos);
		final el = videoItemsEl.children[pos];
		setItemElementType(el, items[pos].isTemp);
	}

	function setPlayer(newPlayer:IPlayer):Void {
		if (player != newPlayer) {
			if (player != null) {
				JsApi.fireVideoRemoveEvents(items[itemPos]);
				player.removeVideo();
			}
			main.blinkTabWithTitle("*Video*");
		}
		player = newPlayer;
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData)->Void):Void {
		var player = players.find(player -> player.isSupportedLink(data.url));
		if (player == null) player = rawPlayer;
		player.getVideoData(data, callback);
	}

	public function isRawPlayerLink(url:String):Bool {
		return !players.exists(player -> player.isSupportedLink(url));
	}

	public function getIframeData(data:VideoDataRequest, callback:(data:VideoData)->Void):Void {
		iframePlayer.getVideoData(data, callback);
	}

	public function setVideo(i:Int):Void {
		if (!main.isSyncActive) return;
		final item = items[i];
		var currentPlayer = players.find(p -> p.isSupportedLink(item.url));
		if (currentPlayer != null) setPlayer(currentPlayer);
		else if (item.isIframe) setPlayer(iframePlayer);
		else setPlayer(rawPlayer);

		final childs = videoItemsEl.children;
		if (childs[itemPos] != null) {
			childs[itemPos].classList.remove("queue_active");
		}
		itemPos = i;
		childs[itemPos].classList.add("queue_active");

		isLoaded = false;
		player.loadVideo(item);
		JsApi.fireVideoChangeEvents(item);
		ge("#currenttitle").textContent = item.title;
	}

	public function changeVideoSrc(src:String):Void {
		if (player == null) return;
		final item = items[itemPos];
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
		JsApi.fireVideoRemoveEvents(items[itemPos]);
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
			type: Play, play: {
				time: getTime()
			}
		});
		if (main.hasLeaderOnPauseRequest()) {
			// do not remove leader if user cannot request it back
			final group:Client.ClientGroup = main.isAdmin() ? Admin : User;
			if (main.hasPermission(group, RequestLeaderPerm)) main.toggleLeader();
		}
	}

	public function onPause():Void {
		if (main.hasLeaderOnPauseRequest() && !main.hasLeader()) {
			JsApi.once(SetLeader, event -> {
				final name = event.setLeader.clientName;
				if (name != main.getName()) return;
				main.send({
					type: Pause, pause: {
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
			type: Pause, pause: {
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
			type: SetTime, setTime: {
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
			type: SetRate, setRate: {
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
		items.addItem(item, atEnd, itemPos);
		setItemElementType(itemEl, item.isTemp);
		if (atEnd) videoItemsEl.appendChild(itemEl);
		else Utils.insertAtIndex(videoItemsEl, itemEl, itemPos + 1);
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
		var index = items.findIndex(item -> item.url == url);
		if (index == -1) return;

		final isCurrent = items[itemPos].url == url;
		itemPos = items.removeItem(index, itemPos);
		updateCounters();

		if (isCurrent && items.length > 0) {
			setVideo(itemPos);
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
		var index = items.findIndex(item -> item.url == url);
		if (index == -1) return;
		if (items[index].isTemp) removeElementItem(url);
		index = items.skipItem(index);
		updateCounters();
		if (items.length == 0) return;
		setVideo(index);
	}

	function updateCounters():Void {
		ge("#plcount").textContent = '${items.length} ${Lang.get("videos")}';
		ge("#pllength").textContent = totalDuration();
	}

	public function getItems():VideoList {
		return items;
	}

	public function setItems(list:Array<VideoItem>, ?pos:Int):Void {
		final currentUrl = itemPos >= items.length ? "" : items[itemPos].url;
		clearItems();
		if (pos != null) itemPos = pos;
		if (list.length == 0) return;
		for (video in list) addVideoItem(video, true);
		if (currentUrl != items[itemPos].url) setVideo(itemPos);
		else videoItemsEl.children[itemPos].classList.add("queue_active");
	}

	public function clearItems():Void {
		items.resize(0);
		videoItemsEl.textContent = "";
		updateCounters();
	}

	public function refresh():Void {
		if (items.length == 0) return;
		final time = getTime();
		removeVideo();
		setVideo(itemPos);
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
		for (item in items) {
			if (item.isIframe) continue;
			time += item.duration;
		}
		return duration(time);
	}

	public function isListEmpty():Bool {
		return items.length == 0;
	}

	public function itemsLength():Int {
		return items.length;
	}

	public function getItemPos():Int {
		return itemPos;
	}

	public function hasVideo():Bool {
		return playerEl.children.length != 0;
	}

	public function getDuration():Float {
		if (itemPos >= items.length) return 0;
		return items[itemPos].duration;
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
