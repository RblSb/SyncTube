package client;

import js.Browser.document;
import client.Main.ge;

class MobileView {

	public static function init():Void {
		final mvbtn = ge("#mv_btn");
		mvbtn.onclick = e -> {
			final mobileView = toggleFullScreen();
			if (mobileView) {
				document.body.classList.add('mobile-view');
				mvbtn.classList.add('active');
				final vwrap = ge("#videowrap");
				if (vwrap.children[0] == ge("currenttitle")) {
					vwrap.appendChild(vwrap.children[0]);
				}
			} else {
				document.body.classList.remove('mobile-view');
				mvbtn.classList.remove('active');
				final vwrap = ge("videowrap");
				if (vwrap.children[0] != ge("currenttitle")) {
					vwrap.insertBefore(vwrap.children[1],vwrap.children[0]);
				}
			}
		}
	}

	static function toggleFullScreen():Bool {
		var state = true;
		final doc:Dynamic = document;
		if (document.fullscreenElement == null &&
			doc.mozFullScreenElement == null &&
			doc.webkitFullscreenElement == null) {
			if (document.documentElement.requestFullscreen != null) {
				document.documentElement.requestFullscreen();
			} else if (doc.documentElement.mozRequestFullScreen != null) {
				doc.documentElement.mozRequestFullScreen();
			} else if (doc.documentElement.webkitRequestFullscreen != null) {
				doc.documentElement.webkitRequestFullscreen(untyped Element.ALLOW_KEYBOARD_INPUT);
			} else state = false;
		} else {
			if (doc.cancelFullScreen != null) doc.cancelFullScreen();
			else if (doc.mozCancelFullScreen != null) doc.mozCancelFullScreen();
			else if (doc.webkitCancelFullScreen != null) doc.webkitCancelFullScreen();
			state = false;
		}
		return state;
	}
}
