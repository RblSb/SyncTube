package client;

import js.html.Element;
import js.Browser.document;
import client.Main.ge;
import client.players.Raw;
import Types.VideoItem;
using StringTools;
using Lambda;

class Player {

	final main:Main;
	final items:Array<VideoItem> = [];
	final videoItemsEl = ge("#queue");
	final playerEl:Element = ge("#ytapiplayer");
	var player:Null<IPlayer>;
	var currentSrc = "";
	var itemPos = 0;
	var isLoaded = false;
	var skipSetTime = false;
	final matchYoutube = ~/v=([A-z0-9_-]+)/;

	public function new(main:Main):Void {
		this.main = main;
	}

	function setPlayer(player:IPlayer):Void {
		this.player = player;
	}

	function isYoutube(url:String):Bool {
		if (!url.contains("youtube.com/")) return false;
		if (!url.contains("youtu.be/")) return false;
		if (!matchYoutube.match(url)) return false;
		return true;
	}

	public function setVideo(i:Int):Void {
		final item = items[i];
		if (isYoutube(item.url)) {} // setPlayer(new Youtube(main, this));
		else setPlayer(new Raw(main, this));

		final childs = videoItemsEl.children;
		if (childs[itemPos] != null) {
			childs[itemPos].classList.remove("queue_active");
		}
		itemPos = i;
		childs[itemPos].classList.add("queue_active");

		currentSrc = item.url;
		playerEl.textContent = "";
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

	public function addVideoItem(item:VideoItem, atEnd:Bool):Void {
		final itemEl = nodeFromString(
			'<li class="queue_entry pluid-0" title="${Lang.get("addedBy")}: ${item.author}">
				<a class="qe_title" href="${item.url}" target="_blank">${item.title.htmlEscape()}</a>
				<span class="qe_time">${duration(item.duration)}</span>
				<div class="qe_clear"></div>
				<div class="btn-group" style="display: inline-block;">
					<button class="btn btn-xs btn-default qbtn-play">
						<span class="glyphicon glyphicon-play"></span>${Lang.get("play")}
					</button>
					<button class="btn btn-xs btn-default qbtn-next">
						<span class="glyphicon glyphicon-share-alt"></span>${Lang.get("skip")}
					</button>
					<button class="btn btn-xs btn-default qbtn-tmp">
						<span class="glyphicon glyphicon-flag"></span>${Lang.get("makePermanent")}
					</button>
					<button class="btn btn-xs btn-default qbtn-delete" id="btn-delete">
						<span class="glyphicon glyphicon-trash"></span>${Lang.get("delete")}
					</button>
				</div>
			</li>'
		);
		if (item.isTemp) itemEl.classList.add("queue_temp");
		final deleteBtn = itemEl.querySelector("#btn-delete");
		deleteBtn.onclick = e -> {
			main.send({
				type: RemoveVideo,
				removeVideo: {
					url: itemEl.querySelector(".qe_title").getAttribute("href")
				}
			});
		}
		if (atEnd) items.push(item);
		else items.insert(itemPos + 1, item);
		if (atEnd) videoItemsEl.appendChild(itemEl);
		else Utils.insertAtIndex(videoItemsEl, itemEl, itemPos + 1);
		updateCounters();
	}

	public function removeItem(url:String):Void {
		for (child in videoItemsEl.children) {
			if (child.querySelector(".qe_title").getAttribute("href") == url) {
				videoItemsEl.removeChild(child);
				break;
			}
		}

		final item = items.find(item -> item.url == url);
		if (item == null) return;
		var index = items.indexOf(item);
		items.remove(item);
		updateCounters();

		if (index < itemPos) {
			itemPos--;
			return;
		}
		if (index != itemPos) return;
		if (items.length == 0) return;
		if (items[index] == null) index = 0;
		setVideo(index);
	}

	public function skipItem(url:String):Void {
		final item = items.find(item -> item.url == url);
		if (item == null) return;
		if (item.isTemp) {
			removeItem(url);
			return;
		}
		var index = items.indexOf(item) + 1;
		if (index >= items.length) index = 0;
		setVideo(index);
	}

	function updateCounters():Void {
		ge("#plcount").textContent = '${items.length} ${Lang.get("videos")}';
		ge("#pllength").textContent = totalDuration();
	}

	public function getItems():Array<VideoItem> {
		return items;
	}

	public function setItems(list:Array<VideoItem>, ?pos:Int):Void {
		clearItems();
		if (pos != null) itemPos = pos;
		if (list.length == 0) return;
		for (video in list) addVideoItem(video, true);
		if (currentSrc != items[itemPos].url) setVideo(itemPos);
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
		return player != null;
	}

	public function play():Void {
		if (player == null) return;
		player.play();
	}

	public function pause():Void {
		if (player == null) return;
		player.pause();
	}

	public function getTime():Float {
		if (player == null) return 0;
		return player.getTime();
	}

	public function setTime(time:Float, isLocal = true):Void {
		if (player == null) return;
		skipSetTime = isLocal;
		player.setTime(time);
	}

}
