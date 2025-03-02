package client.players;

import Types.PlayerType;
import Types.VideoData;
import Types.VideoDataRequest;
import Types.VideoItem;
import client.Main.getEl;
import haxe.Timer;
import js.Browser.document;
import js.Browser;
import js.hlsjs.Hls;
import js.html.Element;
import js.html.InputElement;
import js.html.URL;
import js.html.VideoElement;
import js.html.audio.AudioContext;
import js.html.audio.GainNode;
import js.lib.Uint8Array;

class Raw implements IPlayer {
	final main:Main;
	final player:Player;
	final playerEl:Element = getEl("#ytapiplayer");
	final titleInput:InputElement = getEl("#mediatitle");
	final subsInput:InputElement = getEl("#subsurl");
	final matchName = ~/^(.+)\.(.+)/;
	var controlsHider:Timer;
	var playAllowed = true;
	var video:VideoElement;
	var isHlsPluginLoaded = false;
	var hls:Hls;
	var audioCtx:AudioContext;
	var gainNode:GainNode;

	public function new(main:Main, player:Player) {
		this.main = main;
		this.player = player;
	}

	public function getPlayerType():PlayerType {
		return RawType;
	}

	public function isSupportedLink(url:String):Bool {
		return true;
	}

	public function isHlsItem(url:String, title:String):Bool {
		return url.contains("m3u8") || title.endsWith("m3u8");
	}

	public function getVideoData(data:VideoDataRequest, callback:(data:VideoData) -> Void):Void {
		final url = data.url;

		var title = titleInput.value.trim();
		if (title.length == 0) {
			final decodedUrl = try url.urlDecode() catch (e) url;
			final lastPart = decodedUrl.substr(decodedUrl.lastIndexOf("/") + 1);
			if (matchName.match(lastPart)) title = matchName.matched(1);
			else title = Lang.get("rawVideo");
		}

		final isHls = isHlsItem(url, title);
		if (isHls && !isHlsPluginLoaded) {
			loadHlsPlugin(() -> getVideoData(data, callback));
			return;
		}

		titleInput.value = "";
		final subs = subsInput.value.trim();
		subsInput.value = "";

		getVideoDuration(url, isHls, duration -> {
			if (duration == 0) {
				callback({duration: duration});
				return;
			}
			callback({
				duration: duration,
				title: title,
				subs: subs,
			});
		});
	}

	function getVideoDuration(url:String, isHls:Bool, callback:(duration:Float) ->
		Void, isAnonCrossOrigin = false):Void {
		final video = document.createVideoElement();
		if (isAnonCrossOrigin) video.crossOrigin = "anonymous";
		video.className = "temp-videoplayer";
		video.src = url;
		var tempHls:Hls = null;
		inline function dispose():Void {
			if (playerEl.contains(video)) playerEl.removeChild(video);
			video.onerror = null;
			video.onloadedmetadata = null;
			tempHls?.destroy();
			video.pause();
			video.removeAttribute("src");
			video.load();
		}
		video.onerror = e -> {
			callback(0);
			dispose();
		}
		video.onloadedmetadata = () -> {
			callback(video.duration);
			dispose();
		}
		if (isHls) {
			tempHls = initHlsSource(video, url);
			tempHls.on(Hls.Events.ERROR, (errorType, e) -> {
				callback(0);
				dispose();
			});
		}
		playerEl.prepend(video);
	}

	function loadHlsPlugin(callback:() -> Void):Void {
		final url = "https://cdn.jsdelivr.net/npm/hls.js@latest";
		JsApi.addScriptToHead(url, () -> {
			isHlsPluginLoaded = true;
			callback();
		});
	}

	function initHlsSource(video:VideoElement, url:String, ?hls:Hls):Null<Hls> {
		if (!Hls.isSupported()) return null;
		hls?.detachMedia();
		hls ??= new Hls();
		hls.loadSource(url);
		hls.attachMedia(video);
		return hls;
	}

	public function loadVideo(item:VideoItem):Void {
		final url = main.tryLocalIp(item.url);
		final isHls = isHlsItem(url, item.title);
		if (isHls && !isHlsPluginLoaded) {
			loadHlsPlugin(() -> loadVideo(item));
			return;
		}
		// we need to fully reset element if we had audio handling
		if (audioCtx != null) removeVideo();
		if (video != null) {
			hls?.detachMedia();
			video.src = url;

			var i = video.children.length;
			while (i-- > 0) {
				final child = video.children[i];
				if (child.nodeName == "TRACK") child.remove();
			}
		} else {
			video = document.createVideoElement();
			video.id = "videoplayer";
			video.setAttribute("playsinline", "");
			video.src = url;
			video.oncanplaythrough = player.onCanBePlayed;
			video.onseeking = player.onSetTime;
			video.onplay = e -> {
				playAllowed = true;
				player.onPlay();
			}
			video.onpause = player.onPause;
			video.onratechange = player.onRateChange;
			if (!main.isAutoplayAllowed()) video.muted = true;
			playerEl.appendChild(video);
		}
		if (isHls) hls = initHlsSource(video, url, hls);
		restartControlsHider();

		var subsUrl = item.subs ?? return;
		if (subsUrl.length == 0) return;
		if (subsUrl.startsWith("/")) {
			RawSubs.loadSubs(subsUrl, video);
			return;
		}
		if (!subsUrl.startsWith("http")) {
			final protocol = Browser.location.protocol;
			subsUrl = '$protocol//$subsUrl';
		}
		final subsUri = try {
			new URL(subsUrl);
		} catch (e) {
			Main.instance.serverMessage('Failed to add subs: bad url ($subsUrl)');
			return;
		}
		// make local url as relative path to skip proxy
		if (subsUri.hostname == main.host || subsUri.hostname == main.globalIp) {
			subsUrl = subsUri.pathname;
		}
		RawSubs.loadSubs(subsUrl, video);
	}

	function restartControlsHider():Void {
		video.controls = true;
		if (Utils.isTouch()) return;
		controlsHider?.stop();
		controlsHider = Timer.delay(() -> {
			if (video == null) return;
			video.controls = false;
		}, 3000);
		video.onmousemove = e -> {
			controlsHider?.stop();
			video.controls = true;
			video.onmousemove = null;
		}
	}

	public function boostVolume(volume:Float):Void {
		if (gainNode != null) {
			gainNode.gain.value = volume;
			return;
		}
		if (volume <= 1) return;
		if (video.crossOrigin != "anonymous") {
			final item = player.getCurrentItem() ?? return;
			final isHls = isHlsItem(item.url, item.title);
			getVideoDuration(item.url, isHls, duration -> {
				if (duration == 0) {
					main.serverMessage("Cannot boost volume for this video, no CORS access.");
				} else {
					video.crossOrigin = "anonymous";
					boostVolume(volume);
				}
			}, true);
			return;
		}
		audioCtx ??= Utils.createAudioContext() ?? return;
		final sourceNode = audioCtx.createMediaElementSource(video);
		gainNode = audioCtx.createGain();
		gainNode.gain.value = volume;
		sourceNode.connect(gainNode);
		gainNode.connect(audioCtx.destination);

		// we need silence check if audio context is too picky about cors
		final analyzer = audioCtx.createAnalyser();
		final bufferSize = 256;
		analyzer.fftSize = bufferSize;
		sourceNode.connect(analyzer);
		final arrayBuffer = new Uint8Array(bufferSize);
		inline function isSilence():Bool {
			analyzer.getByteFrequencyData(arrayBuffer);
			var sum = 0;
			for (i in arrayBuffer) sum += i;
			return sum == 0;
		}
		// src refresh should be enough since video with
		// crossOrigin="anonymous" loads finely
		Timer.delay(() -> {
			if (isSilence()) {
				final item = player.getCurrentItem() ?? return;
				video.src = item.url;
				final isHls = isHlsItem(item.url, item.title);
				initHlsSource(video, item.url, hls);
			}
		}, 300);
	}

	function destroyAudioContext():Void {
		if (audioCtx == null) return;
		gainNode = null;
		audioCtx.close();
		audioCtx = null;
	}

	public function removeVideo():Void {
		if (video == null) return;
		destroyAudioContext();
		hls?.detachMedia();
		video.pause();
		video.removeAttribute("src");
		video.load();
		playerEl.removeChild(video);
		video = null;
	}

	public function isVideoLoaded():Bool {
		return video != null;
	}

	public function play():Void {
		if (!playAllowed) return;
		final promise = video.play();
		if (promise == null) return;
		promise.catchError(error -> {
			// Do not try to play video anymore or Chromium will hide play button
			playAllowed = false;
		});
	}

	public function pause():Void {
		video.pause();
	}

	public function isPaused():Bool {
		return video.paused;
	}

	public function getTime():Float {
		return video.currentTime;
	}

	public function setTime(time:Float):Void {
		video.currentTime = time;
	}

	public function getPlaybackRate():Float {
		return video.playbackRate;
	}

	public function setPlaybackRate(rate:Float):Void {
		video.playbackRate = rate;
	}

	public function getVolume():Float {
		return video.volume;
	}

	public function setVolume(volume:Float):Void {
		video.volume = volume;
	}

	public function unmute():Void {
		video.muted = false;
	}
}
