package client;

import js.Browser.document;
import client.Main.ge;

class MobileView {

	public static function init():Void {
		final mvbtn = ge("#mv_btn");
		mvbtn.onclick = e -> {
			final mobileView = Utils.toggleFullScreen(document.documentElement);
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

}
