package client;

import haxe.io.Mime;
import js.Browser.document;
import js.Browser.navigator;
import js.Browser.window;
import js.html.Element;
import js.html.URL;

class Utils {
	public static function isTouch():Bool {
		return js.Syntax.code("'ontouchstart' in window");
	}

	public static function isIOS():Bool {
		return ~/^(iPhone|iPad|iPod)/.match(navigator.platform)
			|| (~/^Mac/.match(navigator.platform) && navigator.maxTouchPoints > 4);
	}

	public static function nodeFromString(div:String):Element {
		final wrapper = document.createDivElement();
		wrapper.innerHTML = div;
		return wrapper.firstElementChild;
	}

	public static function prepend(parent:Element, child:Element):Void {
		if (parent.firstChild == null) parent.appendChild(child);
		else parent.insertBefore(child, parent.firstChild);
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
		} else if (el2.mozRequestFullScreen != null) {
			el2.mozRequestFullScreen();
		} else if (el2.webkitRequestFullscreen != null) {
			el2.webkitRequestFullscreen(untyped Element.ALLOW_KEYBOARD_INPUT);
		} else return false;
		return true;
	}

	public static function cancelFullscreen(el:Element):Void {
		final doc:Dynamic = document;
		if (doc.cancelFullScreen != null) doc.cancelFullScreen();
		else if (doc.mozCancelFullScreen != null) doc.mozCancelFullScreen();
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

	public static function browseFileUrl(
		onFileLoad:(url:String, name:String) -> Void,
		isBinary = true,
		revoke = false
	):Void {
		final input = document.createElement("input");
		input.style.visibility = "hidden";
		input.setAttribute("type", "file");
		input.id = "browse";
		input.onclick = function(e) {
			e.cancelBubble = true;
			e.stopPropagation();
		}
		input.onchange = function() {
			final file:Dynamic = (input : Dynamic).files[0];
			final url = URL.createObjectURL(file);
			onFileLoad(url, file.name);
			document.body.removeChild(input);
			if (revoke) URL.revokeObjectURL(url);
		}
		document.body.appendChild(input);
		input.click();
	}

	public static function saveFile(name:String, mime:Mime, data:String):Void {
		final blob = new js.html.Blob([data], {
			type: mime
		});
		final url = URL.createObjectURL(blob);
		final a = document.createElement("a");
		untyped a.download = name;
		untyped a.href = url;
		a.onclick = function(e) {
			e.cancelBubble = true;
			e.stopPropagation();
		}
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
		URL.revokeObjectURL(url);
	}
}
