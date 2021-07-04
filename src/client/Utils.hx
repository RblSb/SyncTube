package client;

import js.Browser.document;
import js.Browser.window;
import js.html.Element;

class Utils {
	public static function isTouch():Bool {
		return js.Syntax.code("'ontouchstart' in window");
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
}
