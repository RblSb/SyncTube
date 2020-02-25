package client;

import js.html.Element;
import js.html.VideoElement;
import js.Browser.document;
import client.Main.ge;
import Types.VideoItem;
using Lambda;

class Player {

	final main:Main;
	final items:Array<VideoItem> = [];
	final videoItemsEl = ge("#queue");
	final player:Element = ge("#ytapiplayer");
	var isLoaded = false;
	var skipSetTime = false;
	var video:VideoElement;

	public function new(main:Main):Void {
		this.main = main;
	}

	public function setVideo(item:VideoItem):Void {
		isLoaded = false;
		video = document.createVideoElement();
		video.id = "videoplayer";
		item.url = main.tryLocalIp(item.url);
		video.src = item.url;
		video.controls = true;
		video.oncanplaythrough = e -> {
			if (!isLoaded) main.send({type: VideoLoaded});
			isLoaded = true;
		}
		video.onseeking = e -> {
			if (skipSetTime) {
				skipSetTime = false;
				return;
			}
			if (!main.isLeader()) return;
			main.send({
				type: SetTime,
				setTime: {
					time: video.currentTime
				}
			});
		}
		video.onpause = e -> {
			if (!main.isLeader()) return;
			main.send({
				type: Pause,
				pause: {
					time: video.currentTime
				}
			});
		}
		video.onplay = e -> {
			if (!main.isLeader()) return;
			main.send({
				type: Play,
				play: {
					time: video.currentTime
				}
			});
		}
		player.innerHTML = "";
		player.appendChild(video);
		ge("#currenttitle").innerHTML = item.title;
	}

	public function addVideoItem(item:VideoItem, atEnd:Bool):Void {
		items.push(item);
		final itemEl = nodeFromString(
			'<li class="queue_entry pluid-0 queue_temp queue_active" title="${Lang.get("addedBy")}: ${item.author}">
				<a class="qe_title" href="${item.url}" target="_blank">${item.title}</a>
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
		final deleteBtn = itemEl.querySelector("#btn-delete");
		deleteBtn.onclick = e -> {
			main.send({
				type: RemoveVideo,
				removeVideo: {
					url: itemEl.querySelector(".qe_title").getAttribute("href")
				}
			});
		}
		if (atEnd) videoItemsEl.appendChild(itemEl);
		else Utils.insertAtIndex(videoItemsEl, itemEl, 1);
		updateCounters();
	}

	public function removeVideo():Void {
		if (video == null) return;
		player.removeChild(video);
		video = null;
		ge("#currenttitle").innerHTML = Lang.get("nothingPlaying");
	}

	public function removeItem(url:String):Void {
		for (child in videoItemsEl.children) {
			if (child.querySelector(".qe_title").getAttribute("href") == url) {
				videoItemsEl.removeChild(child);
				break;
			}
		}

		items.remove(
			items.find(item -> item.url == url)
		);
		updateCounters();

		if (video == null) return;
		if (video.src == url) {
			if (items.length > 0) setVideo(items[0]);
		}
	}

	function updateCounters():Void {
		ge("#plcount").innerHTML = '${items.length} ${Lang.get("videos")}';
		ge("#pllength").innerHTML = totalDuration();
	}

	public function getItems():Array<VideoItem> {
		return items;
	}

	public function setItems(list:Array<VideoItem>):Void {
		clearItems();
		if (list.length == 0) return;
		if (video == null || video.src != list[0].url) {
			setVideo(list[0]);
		}
		for (video in list) {
			addVideoItem(video, true);
		}
	}

	public function clearItems():Void {
		items.resize(0);
		videoItemsEl.innerHTML = "";
		updateCounters();
	}

	public function refresh():Void {
		if (items.length == 0) return;
		removeVideo();
		setVideo(items[0]);
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

	public function hasVideo():Bool {
		return video != null;
	}

	public function pause():Void {
		if (video == null) return;
		video.pause();
	}

	public function play():Void {
		if (video == null) return;
		video.play();
	}

	public function setTime(time:Float, isLocal = true):Void {
		if (video == null) return;
		skipSetTime = isLocal;
		video.currentTime = time;
	}

	public function getTime():Float {
		if (video == null) return 0;
		return video.currentTime;
	}

}
