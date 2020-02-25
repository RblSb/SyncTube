package client;

import js.Browser.document;
import client.Main.ge;

class MobileView {

	public static function init():Void {
		final mvbtn = ge("#mv_btn");
		mvbtn.onclick = e -> {
			final hasMobileView = Utils.toggleFullScreen(document.documentElement);
			final vwrap = ge("#videowrap");
			if (hasMobileView) {
				document.body.classList.add("mobile-view");
				mvbtn.classList.add("active");
				if (vwrap.children[0].id == "currenttitle") {
					vwrap.appendChild(vwrap.children[0]);
				}
			} else {
				document.body.classList.remove("mobile-view");
				mvbtn.classList.remove("active");
				if (vwrap.children[0].id != "currenttitle") {
					vwrap.insertBefore(vwrap.children[1], vwrap.children[0]);
				}
			}
		}
	}

}
