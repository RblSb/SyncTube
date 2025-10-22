package client;

import Types.UploadResponse;
import client.Main.getEl;
import haxe.Json;
import haxe.Timer;
import js.Browser.window;
import js.html.File;
import js.html.InputElement;
import js.html.ProgressEvent;
import js.html.XMLHttpRequest;

class FileUploader {
	final main:Main;

	public function new(main:Main) {
		this.main = main;
	}

	public function uploadFile(file:File):Void {
		var name = ~/[?#%\/\\]/g.replace(file.name, "").trim();
		if (name.length == 0) name = "video";
		name = (window : Dynamic).encodeURIComponent(name);

		// send last chunk separately to allow server file streaming while uploading
		uploadLastChunk(file, name, data -> {
			if (data.errorId != null) {
				main.serverMessage(data.info, true, false);
				return;
			}
			final input:InputElement = getEl("#mediaurl");
			input.value = data.url;

			uploadFullFile(name, file);
		});
	}

	function uploadFullFile(name:String, file:File):Void {
		final request = new XMLHttpRequest();
		request.open("POST", "/upload", true);
		request.setRequestHeader("content-name", name);

		request.upload.onprogress = (event:ProgressEvent) -> {
			var ratio = 0.0;
			if (event.lengthComputable) {
				ratio = (event.loaded / event.total).clamp(0, 1);
			}
			main.onProgressEvent({
				type: Progress,
				progress: {
					type: Uploading,
					ratio: ratio
				}
			});
		}

		request.onload = (e:ProgressEvent) -> {
			final data:UploadResponse = try {
				Json.parse(request.responseText);
			} catch (e) {
				trace(e);
				return;
			}
			if (data.errorId == null) return;
			main.serverMessage(data.info, true, false);
		}
		request.onloadend = () -> {
			Timer.delay(() -> {
				main.hideDynamicChin();
			}, 500);
		}

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
		chunkReq.then(e -> {
			e.json().then((data:UploadResponse) -> {
				callback(data);
			});
		});
	}
}
