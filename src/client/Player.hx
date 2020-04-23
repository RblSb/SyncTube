package client;

import js.html.Element;
import js.Browser.document;
import client.Main.ge;
import client.players.Raw;
import client.players.Youtube;
import client.players.Iframe;
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
	var currentSrc = "";
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
		items.setNextItem(pos, itemPos);

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
		if (player != null && player != newPlayer) {
			player.removeVideo();
			// playerEl.textContent = "";
		}
		player = newPlayer;
	}

	public function getVideoData(url:String, callback:(data:VideoData)->Void):Void {
		var player = players.find(player -> player.isSupportedLink(url));
		if (player == null) player = rawPlayer;
		player.getVideoData(url, callback);
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

		currentSrc = item.url;
		isLoaded = false;
		player.loadVideo(item);
		ge("#currenttitle").textContent = item.title;
	}

	public function removeVideo():Void {
		currentSrc = "";
		player.removeVideo();
		ge("#currenttitle").textContent = Lang.get("nothingPlaying");
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
	}

	public function onPause():Void {
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
		final itemEl = nodeFromString(
			'<li class="queue_entry pluid-0" title="${Lang.get("addedBy")}: ${item.author}">
				<a class="qe_title" href="$url" target="_blank">${item.title.htmlEscape()}</a>
				<span class="qe_time">${duration(item.duration)}</span>
				<div class="qe_clear"></div>
				<div class="btn-group">
					<button class="btn btn-xs btn-default qbtn-play">
						<span class="glyphicon glyphicon-play"></span>${Lang.get("play")}
					</button>
					<button class="btn btn-xs btn-default qbtn-next">
						<span class="glyphicon glyphicon-share-alt"></span>${Lang.get("setNext")}
					</button>
					<button class="btn btn-xs btn-default qbtn-tmp">
						<span class="glyphicon glyphicon-flag"></span>
					</button>
					<button class="btn btn-xs btn-default qbtn-delete">
						<span class="glyphicon glyphicon-trash"></span>${Lang.get("delete")}
					</button>
				</div>
			</li>'
		);
		items.addItem(item, atEnd, itemPos);
		setItemElementType(itemEl, item.isTemp);
		if (atEnd) videoItemsEl.appendChild(itemEl);
		else Utils.insertAtIndex(videoItemsEl, itemEl, itemPos + 1);
		updateCounters();
	}

	function setItemElementType(item:Element, isTemp:Bool):Void {
		final text = isTemp ? Lang.get("makePermanent") : Lang.get("makeTemporary");
		item.querySelector(".qbtn-tmp").innerHTML = '<span class="glyphicon glyphicon-flag"></span>$text';
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
		clearItems();
		if (pos != null) itemPos = pos;
		if (list.length == 0) return;
		for (video in list) addVideoItem(video, true);
		if (currentSrc != items[itemPos].url) setVideo(itemPos);
		else videoItemsEl.children[itemPos].classList.add("queue_active");
	}

	public function clearItems():Void {
		items.resize(0);
		videoItemsEl.textContent = "";
		updateCounters();
	}

	public function refresh():Void {
		if (items.length == 0) return;
		removeVideo();
		setVideo(itemPos);
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
		for (item in items) time += item.duration;
		return duration(time);
	}

	function nodeFromString(div:String):Element {
		final wrapper = document.createDivElement();
		wrapper.innerHTML = div;
		return wrapper.firstElementChild;
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

	public function play():Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		player.play();
	}

	public function pause():Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		player.pause();
	}

	public function getDuration():Float {
		if (itemPos >= items.length) return 0;
		return items[itemPos].duration;
	}

	public function getTime():Float {
		if (player == null) return 0;
		return player.getTime();
	}

	public function setTime(time:Float, isLocal = true):Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		skipSetTime = isLocal;
		player.setTime(time);
	}

	public function getPlaybackRate():Float {
		if (player == null) return 1;
		return player.getPlaybackRate();
	}

	public function setPlaybackRate(rate:Float, isLocal = true):Void {
		if (!main.isSyncActive) return;
		if (player == null) return;
		skipSetRate = isLocal;
		player.setPlaybackRate(rate);
	}

}
