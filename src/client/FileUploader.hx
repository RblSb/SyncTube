package client;

import Types.ProgressType;
import Types.UploadResponse;
import client.Main.getEl;
import haxe.Json;
import js.Browser.document;
import js.Browser.window;
import js.html.File;
import js.html.InputElement;
import js.html.ProgressEvent;
import js.html.URL;
import js.html.XMLHttpRequest;

class FileUploader {
	final main:Main;

	public function new(main:Main) {
		this.main = main;
	}

	public function uploadFile(file:File):Void {
		var title = ~/[?#%\/\\]/g.replace(file.name, "").trim();
		if (title.length == 0) title = "video";
		final name = title.urlEncode();

		final checkboxTemp:InputElement = getEl("#addfromurl .add-temp");
		final isTemp = Main.isTempChecked(checkboxTemp);

		// send last chunk separately to allow server file streaming while uploading
		uploadLastChunk(file, name, data -> {
			if (data.errorId != null || data.url == null) {
				main.serverMessage(data.info ?? Lang.get("addVideoError"), true, false);
				return;
			}
			final url = data.url;
			getFileDuration(file, duration -> {
				if (duration == 0 || Math.isNaN(duration) || !Math.isFinite(duration)) {
					main.serverMessage(Lang.get("addVideoError"), true, false);
					return;
				}
				uploadFullFile(name, file, url, () -> {
					main.addUploadedVideo(url, title, duration, true, isTemp);
				});
			});
		});
	}

	function getFileDuration(file:File, callback:(duration:Float) -> Void):Void {
		final objUrl = URL.createObjectURL(file);
		final video = document.createVideoElement();
		video.preload = "metadata";
		video.muted = true;
		video.onloadedmetadata = () -> {
			final duration = video.duration;
			URL.revokeObjectURL(objUrl);
			callback(duration);
		}
		video.onerror = e -> {
			URL.revokeObjectURL(objUrl);
			callback(0);
		}
		video.src = objUrl;
	}

	function uploadFullFile(name:String, file:File, url:String, onStarted:() -> Void):Void {
		final resolvedName = url.substr(url.lastIndexOf("/") + 1);
		final headerName = resolvedName.length > 0 ? resolvedName.urlEncode() : name;
		final request = new XMLHttpRequest();
		request.open("POST", "/upload", true);
		request.setRequestHeader("content-name", headerName);

		var added = false;
		function ensureAdded():Void {
			if (added) return;
			added = true;
			onStarted();
			main.registerUpload(url, () -> request.abort());
		}

		function sendProgress(type:ProgressType, ratio:Float):Void {
			main.send({
				type: Progress,
				progress: {
					type: type,
					ratio: ratio,
					url: url
				}
			});
		}

		var lastSentRatio = 0.0;
		request.upload.onprogress = (event:ProgressEvent) -> {
			ensureAdded();
			var ratio = 0.0;
			if (event.lengthComputable) {
				ratio = (event.loaded / event.total).clamp(0, 1);
			}
			if (ratio - lastSentRatio < 0.01 && ratio < 1) return;
			lastSentRatio = ratio;
			sendProgress(Uploading, ratio);
		}

		request.onload = (e:ProgressEvent) -> {
			main.unregisterUpload(url);
			final data:UploadResponse = try {
				Json.parse(request.responseText);
			} catch (e) {
				trace(e);
				sendProgress(Canceled, 0);
				return;
			}
			if (data.errorId != null) {
				main.serverMessage(data.info, true, false);
				sendProgress(Canceled, 0);
				return;
			}
			ensureAdded();
			sendProgress(Completed, 1);
		}
		request.onerror = (e:ProgressEvent) -> {
			main.unregisterUpload(url);
			sendProgress(Canceled, 0);
		}
		request.onabort = (e:ProgressEvent) -> main.unregisterUpload(url);

		request.send(file);
	}

	function uploadLastChunk(file:File, name:String, callback:(data:UploadResponse) -> Void):Void {
		final chunkSize = 1024 * 1024 * 5; // 5 MB
		final bufferOffset = (file.size - chunkSize).limitMin(0);
		final lastChunk = file.slice(bufferOffset);
		final chunkReq = window.fetch("/upload-last-chunk", {
			method: "POST",
			headers: {
				"content-name": name,
			},
			body: lastChunk,
		});
		chunkReq.then(e -> e.json()).then((data:UploadResponse) -> {
			callback(data);
		}).catchError(err -> {
			trace(err);
			main.serverMessage(Lang.get("addVideoError"), true, false);
		});
	}
}
