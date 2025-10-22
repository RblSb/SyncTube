package client;

import haxe.io.Mime;
import js.Browser.document;
import js.Browser.navigator;
import js.Browser.window;
import js.html.Blob;
import js.html.Element;
import js.html.File;
import js.html.FileReader;
import js.html.URL;
import js.html.audio.AudioContext;
import js.lib.ArrayBuffer;

class Utils {
	public static function nativeTrace(msg:Dynamic, ?infos:haxe.PosInfos):Void {
		final fileData = '${infos.fileName}:${infos.lineNumber}';
		var args:Array<Dynamic> = [fileData, msg];
		if (infos.customParams != null) args = args.concat(infos.customParams);
		js.Browser.window.console.log(
			...haxe.Rest.of(args)
		);
	}

	public static function isTouch():Bool {
		return js.Syntax.code("'ontouchstart' in window");
	}

	public static function isIOS():Bool {
		return ~/^(iPhone|iPad|iPod)/.match(navigator.platform)
			|| (~/^Mac/.match(navigator.platform) && navigator.maxTouchPoints > 4);
	}

	public static var isMacSafari = _isMacSafari();

	static function _isMacSafari():Bool {
		final isMac = navigator.userAgent.contains("Macintosh");
		final isSafari = navigator.userAgent.contains("Safari")
			&& !navigator.userAgent.contains("Chrom")
			&& !navigator.userAgent.contains("Edg");
		return isMac && isSafari;
	}

	public static function isAndroid():Bool {
		final ua = navigator.userAgent.toLowerCase();
		return ua.indexOf("android") > -1;
	}

	public static function nodeFromString(div:String):Element {
		final wrapper = document.createDivElement();
		wrapper.innerHTML = div;
		return wrapper.firstElementChild;
	}

	public static function outerHeight(el:Element):Float {
		final style = window.getComputedStyle(el);
		return (el.getBoundingClientRect().height
			+ Std.parseFloat(style.marginTop)
			+ Std.parseFloat(style.marginBottom));
	}

	public static function insertAtIndex(parent:Element, child:Element, i:Int) {
		if (i >= parent.children.length) parent.appendChild(child);
		else parent.insertBefore(child, parent.children[i]);
	}

	public static function getIndex(parent:Element, child:Element):Int {
		var i = 0;
		for (el in parent.children) {
			if (el == child) break;
			i++;
		}
		return i;
	}

	public static function hasFullscreen():Bool {
		final doc:Dynamic = document;
		return (document.fullscreenElement != null || doc.mozFullScreenElement != null
			|| doc.webkitFullscreenElement != null);
	}

	public static function requestFullscreen(el:Element):Bool {
		final el2:Dynamic = el;
		if (el.requestFullscreen != null) {
			el.requestFullscreen();
		} else if (el2.webkitRequestFullscreen != null) {
			el2.webkitRequestFullscreen(untyped Element.ALLOW_KEYBOARD_INPUT);
		} else return false;
		return true;
	}

	public static function cancelFullscreen(el:Element):Void {
		final doc:Dynamic = document;
		if (doc.cancelFullScreen != null) doc.cancelFullScreen();
		else if (doc.webkitCancelFullScreen != null) doc.webkitCancelFullScreen();
	}

	public static function toggleFullscreen(el:Element):Bool {
		if (hasFullscreen()) {
			cancelFullscreen(el);
			return false;
		}
		return requestFullscreen(el);
	}

	public static function copyToClipboard(text:String):Void {
		final clipboardData = (window : Dynamic).clipboardData;
		if (clipboardData != null && clipboardData.setData != null) {
			// IE-specific code path to prevent textarea being shown while dialog is visible.
			clipboardData.setData("Text", text);
			return;
		} else if ((document : Dynamic).queryCommandSupported != null) {
			final textarea = document.createTextAreaElement();
			textarea.textContent = text;
			// Prevent scrolling to bottom of page in Microsoft Edge.
			textarea.style.position = "fixed";
			document.body.appendChild(textarea);
			textarea.select();
			try {
				// Security exception may be thrown by some browsers.
				document.execCommand("copy");
			}
			document.body.removeChild(textarea);
		}
	}

	public static function matchedNum(ereg:EReg):Int {
		#if js
		return (ereg : Dynamic).r.m.length;
		#else
		#error "not implemented"
		#end
	}

	public static function browseFile(
		onFileLoad:(buffer:ArrayBuffer, name:String) -> Void
	):Void {
		browseFileImpl(onFileLoad, true, false);
	}

	public static function browseFileUrl(
		onFileLoad:(url:String, name:String) -> Void,
		revoke = false
	):Void {
		browseFileImpl(onFileLoad, false, revoke);
	}

	static function browseFileImpl(
		onFileLoad:(data:Dynamic, name:String) -> Void,
		isBinary:Bool,
		revokeAfterLoad:Bool
	):Void {
		final input = document.createInputElement();
		input.style.visibility = "hidden";
		input.type = "file";
		input.id = "browse";
		input.onclick = e -> {
			e.cancelBubble = true;
			e.stopPropagation();
		}
		input.onchange = e -> {
			final file = input.files[0] ?? return;
			if (!isBinary) {
				final url = URL.createObjectURL(file);
				onFileLoad(url, file.name);
				document.body.removeChild(input);
				if (revokeAfterLoad) URL.revokeObjectURL(url);
				return;
			}
			final reader = new FileReader();
			reader.onload = e -> {
				final result:ArrayBuffer = reader.result;
				onFileLoad(result, file.name);
				document.body.removeChild(input);
			}
			reader.onerror = e -> {
				document.body.removeChild(input);
			}
			reader.readAsArrayBuffer(file);
		}
		document.body.appendChild(input);
		input.click();
	}

	/** Don't extract data for bigger files. **/
	public static function browseJsFile(
		onFileSelected:(file:File) -> Void
	):Void {
		final input = document.createInputElement();
		input.style.visibility = "hidden";
		input.type = "file";
		input.id = "browse";
		input.onclick = e -> {
			e.cancelBubble = true;
			e.stopPropagation();
		}
		input.onchange = e -> {
			final file = input.files[0] ?? return;
			onFileSelected(file);
		}
		document.body.appendChild(input);
		input.click();
	}

	public static function saveFile(name:String, mime:Mime, data:String):Void {
		final blob = new Blob([data], {
			type: mime
		});
		final url = URL.createObjectURL(blob);
		final a = document.createAnchorElement();
		a.download = name;
		a.href = url;
		a.onclick = e -> {
			e.cancelBubble = true;
			e.stopPropagation();
		}
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
		URL.revokeObjectURL(url);
	}

	public static function createResizeObserver(callback:(entries:Array<Dynamic>) -> Void):Null<{
		observe:(el:Element) -> Void
	}> {
		final window = js.Browser.window;
		final observer = (window : Dynamic).ResizeObserver ?? return null;
		return js.Syntax.code("new ResizeObserver({0})", callback);
	}

	public static function createAudioContext():Null<AudioContext> {
		final w:Dynamic = js.Browser.window;
		final ctx = w.AudioContext ?? w.webkitAudioContext ?? return null;
		return js.Syntax.code("new {0}()", ctx);
	}
}
